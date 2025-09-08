#!/usr/bin/env python3
"""
Enhanced Persistence Service for Multi-Agent Docker Dev Environments
Based on Claude file-saver concept, extended for spec-driven development
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
import yaml
import hashlib
from datetime import datetime
from typing import Dict, List, Any, Optional
import git
from pathlib import Path
import structlog

# Configure structured logging
logger = structlog.get_logger()

app = Flask(__name__)
CORS(app)

# Configuration
WORKSPACE_DIR = os.getenv('WORKSPACE_DIR', '/workspace')
SPECS_DIR = os.getenv('SPECS_DIR', '/specs')
OUTPUTS_DIR = os.getenv('OUTPUTS_DIR', '/outputs')
VALIDATE_SPECS = os.getenv('VALIDATE_SPECS', 'true').lower() == 'true'
AUTO_COMMIT = os.getenv('AUTO_COMMIT', 'true').lower() == 'true'
TDD_MODE = os.getenv('TDD_MODE', 'enforced')

class SpecValidator:
    """Validates outputs against specifications"""
    
    def __init__(self, specs_dir: str):
        self.specs_dir = specs_dir
        self.specs_cache = {}
    
    def load_spec(self, spec_name: str) -> Dict:
        """Load specification from YAML file"""
        if spec_name in self.specs_cache:
            return self.specs_cache[spec_name]
        
        spec_path = Path(self.specs_dir) / f"{spec_name}.yaml"
        if not spec_path.exists():
            return None
        
        with open(spec_path, 'r') as f:
            spec = yaml.safe_load(f)
            self.specs_cache[spec_name] = spec
            return spec
    
    def validate_output(self, filename: str, content: str, spec_name: str) -> Dict:
        """Validate file output against specification"""
        spec = self.load_spec(spec_name)
        if not spec:
            return {'valid': True, 'message': 'No specification found'}
        
        validation_result = {
            'valid': True,
            'errors': [],
            'warnings': []
        }
        
        # Find matching output spec
        for output_spec in spec.get('outputs', []):
            if output_spec['path'] == filename:
                # Check required elements
                for element in output_spec.get('required_elements', []):
                    if element not in content:
                        validation_result['valid'] = False
                        validation_result['errors'].append(
                            f"Missing required element: {element}"
                        )
                
                # Check TDD phase
                if TDD_MODE == 'enforced':
                    phase = output_spec.get('phase')
                    if phase == 'green' and not self.tests_exist(spec_name):
                        validation_result['valid'] = False
                        validation_result['errors'].append(
                            "Implementation created before tests (violates TDD)"
                        )
                
                break
        
        return validation_result

    def tests_exist(self, spec_name: str) -> bool:
        """Check if test files exist for a specification"""
        spec = self.load_spec(spec_name)
        if not spec:
            return True  # Assume tests exist if no spec
        
        for output in spec.get('outputs', []):
            if output.get('type') == 'test':
                test_path = Path(WORKSPACE_DIR) / output['path']
                if test_path.exists():
                    return True
        return False

class PersistenceManager:
    """Manages file persistence with version control"""
    
    def __init__(self, workspace_dir: str):
        self.workspace_dir = workspace_dir
        self.ensure_git_repo()
    
    def ensure_git_repo(self):
        """Ensure workspace is a git repository"""
        try:
            self.repo = git.Repo(self.workspace_dir)
        except git.InvalidGitRepositoryError:
            self.repo = git.Repo.init(self.workspace_dir)
            logger.info("Initialized git repository", path=self.workspace_dir)
    
    def save_file(self, filename: str, content: str, metadata: Dict = None) -> Dict:
        """Save file with optional git commit"""
        filepath = Path(self.workspace_dir) / filename
        
        # Create directories if needed
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        # Generate checksum for change detection
        new_checksum = hashlib.md5(content.encode()).hexdigest()
        
        # Check if file exists and has changed
        file_exists = filepath.exists()
        if file_exists:
            with open(filepath, 'r') as f:
                old_content = f.read()
                old_checksum = hashlib.md5(old_content.encode()).hexdigest()
                if old_checksum == new_checksum:
                    return {
                        'status': 'unchanged',
                        'message': f'File {filename} unchanged',
                        'checksum': new_checksum
                    }
        
        # Write file
        with open(filepath, 'w') as f:
            f.write(content)
        
        # Auto-commit if enabled
        if AUTO_COMMIT:
            self.commit_file(filename, metadata)
        
        return {
            'status': 'saved',
            'message': f'File {filename} saved successfully',
            'checksum': new_checksum,
            'new_file': not file_exists
        }
    
    def commit_file(self, filename: str, metadata: Dict = None):
        """Commit file to git with metadata"""
        try:
            self.repo.index.add([filename])
            
            # Generate commit message
            agent = metadata.get('agent', 'unknown') if metadata else 'unknown'
            phase = metadata.get('tdd_phase', 'implementation') if metadata else 'implementation'
            spec = metadata.get('spec_name', '') if metadata else ''
            
            commit_msg = f"[{agent}] {phase}: {filename}"
            if spec:
                commit_msg += f" (spec: {spec})"
            
            self.repo.index.commit(commit_msg)
            logger.info("Committed file", filename=filename, message=commit_msg)
        except Exception as e:
            logger.error("Failed to commit file", filename=filename, error=str(e))

# Initialize components
validator = SpecValidator(SPECS_DIR)
persistence = PersistenceManager(WORKSPACE_DIR)

@app.route('/save', methods=['POST'])
def save_file():
    """Enhanced file saving endpoint with validation and persistence"""
    data = request.json
    filename = data.get('filename')
    content = data.get('content')
    metadata = data.get('metadata', {})
    
    if not filename or content is None:
        return jsonify({
            'status': 'error',
            'message': 'Missing filename or content'
        }), 400
    
    try:
        # Validate against specification if provided
        spec_name = metadata.get('spec_name')
        if VALIDATE_SPECS and spec_name:
            validation = validator.validate_output(filename, content, spec_name)
            if not validation['valid']:
                return jsonify({
                    'status': 'error',
                    'message': 'Validation failed',
                    'validation': validation
                }), 400
        
        # Save file
        result = persistence.save_file(filename, content, metadata)
        
        # Log agent activity
        logger.info(
            "File saved by agent",
            filename=filename,
            agent=metadata.get('agent', 'unknown'),
            spec=spec_name,
            tdd_phase=metadata.get('tdd_phase', 'unknown')
        )
        
        return jsonify(result)
        
    except Exception as e:
        logger.error("Failed to save file", filename=filename, error=str(e))
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/validate', methods=['POST'])
def validate_spec():
    """Validate a file against its specification"""
    data = request.json
    filename = data.get('filename')
    content = data.get('content')
    spec_name = data.get('spec_name')
    
    if not all([filename, content, spec_name]):
        return jsonify({
            'status': 'error',
            'message': 'Missing required parameters'
        }), 400
    
    validation = validator.validate_output(filename, content, spec_name)
    return jsonify(validation)

@app.route('/specs', methods=['GET'])
def list_specs():
    """List available specifications"""
    specs_path = Path(SPECS_DIR)
    if not specs_path.exists():
        return jsonify([])
    
    specs = []
    for spec_file in specs_path.glob('*.yaml'):
        with open(spec_file, 'r') as f:
            spec = yaml.safe_load(f)
            specs.append({
                'name': spec_file.stem,
                'feature': spec.get('feature', {}).get('name', 'Unknown'),
                'type': spec.get('feature', {}).get('type', 'Unknown')
            })
    
    return jsonify(specs)

@app.route('/status', methods=['GET'])
def status():
    """Get persistence service status"""
    return jsonify({
        'service': 'persistence-service',
        'version': '1.0.0',
        'workspace': WORKSPACE_DIR,
        'specs_dir': SPECS_DIR,
        'validate_specs': VALIDATE_SPECS,
        'auto_commit': AUTO_COMMIT,
        'tdd_mode': TDD_MODE
    })

if __name__ == '__main__':
    # Ensure directories exist
    for dir_path in [WORKSPACE_DIR, SPECS_DIR, OUTPUTS_DIR]:
        Path(dir_path).mkdir(parents=True, exist_ok=True)
    
    app.run(debug=True, host='0.0.0.0', port=5000)