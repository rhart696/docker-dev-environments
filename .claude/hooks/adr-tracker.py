#!/usr/bin/env python3
"""
ADR Tracker Hook for Claude Code
Automatically generates ADRs for significant architectural decisions
"""

import os
import re
import json
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

class ADRTracker:
    """Tracks and generates Architecture Decision Records automatically"""
    
    def __init__(self):
        self.project_root = Path.cwd()
        self.adr_dir = self.project_root / "docs" / "adr"
        self.decision_patterns = [
            r'(switch|migrate|replace).*(from|to)',
            r'(adopt|implement|add)\s+\w+\s+(framework|library|pattern)',
            r'(remove|deprecate|delete)',
            r'(refactor|restructure|reorganize)',
            r'breaking.?change',
            r'BREAKING',
        ]
        self.significance_threshold = 3  # Complexity score threshold
        
    def hook_post_code_generation(self, context: Dict) -> Optional[Dict]:
        """
        Analyzes generated code for architectural decisions
        """
        code = context.get('generated_code', '')
        file_path = context.get('file_path', '')
        description = context.get('description', '')
        
        # Check if this might be an architectural decision
        decision_score = self._calculate_decision_score(code, description)
        
        if decision_score >= self.significance_threshold:
            suggestion = self._generate_adr_suggestion(context, decision_score)
            return {
                'adr_suggested': True,
                'score': decision_score,
                'suggestion': suggestion,
                'auto_create': decision_score >= 5
            }
        
        return None
    
    def hook_pre_commit(self, context: Dict) -> Tuple[bool, str]:
        """
        Checks if significant changes need ADR documentation
        """
        changed_files = context.get('changed_files', [])
        commit_message = context.get('message', '')
        
        # Check for significant architectural changes
        significant_changes = self._detect_significant_changes(changed_files)
        
        if significant_changes and not self._has_recent_adr():
            # Suggest creating an ADR
            return (True, 
                   f"⚠️  Significant architectural changes detected:\n"
                   f"{chr(10).join('  - ' + c for c in significant_changes)}\n\n"
                   f"Consider creating an ADR:\n"
                   f"  ./scripts/create-adr.sh \"{self._suggest_adr_title(commit_message)}\"")
        
        return (True, "✅ No ADR required for these changes")
    
    def _calculate_decision_score(self, code: str, description: str) -> int:
        """
        Calculate significance score for potential architectural decision
        """
        score = 0
        
        # Check for decision patterns in description
        for pattern in self.decision_patterns:
            if re.search(pattern, description, re.IGNORECASE):
                score += 2
        
        # Check code complexity indicators
        if 'class' in code or 'interface' in code:
            score += 1
        if 'async' in code or 'await' in code:
            score += 1
        if 'docker' in code.lower() or 'container' in code.lower():
            score += 2
        if 'test' in code.lower() or 'spec' in code.lower():
            score += 1
        
        # Check for configuration changes
        if any(ext in str(code) for ext in ['.yml', '.yaml', '.json', '.toml']):
            score += 2
        
        # Check for new dependencies
        if 'import' in code or 'require' in code or 'FROM' in code:
            score += 1
        
        return score
    
    def _detect_significant_changes(self, files: List[str]) -> List[str]:
        """
        Detect significant architectural changes from file list
        """
        significant = []
        
        # Architecture-significant file patterns
        significant_patterns = [
            (r'Dockerfile', "Docker configuration changed"),
            (r'docker-compose.*\.yml', "Service orchestration changed"),
            (r'package\.json', "Dependencies changed"),
            (r'requirements\.txt', "Python dependencies changed"),
            (r'\.github/workflows/', "CI/CD pipeline changed"),
            (r'tsconfig\.json', "TypeScript configuration changed"),
            (r'webpack\.config', "Build configuration changed"),
            (r'nginx\.conf', "Server configuration changed"),
            (r'.*\.proto$', "API contracts changed"),
            (r'migration', "Database schema changed"),
        ]
        
        for file in files:
            for pattern, description in significant_patterns:
                if re.search(pattern, file):
                    significant.append(description)
                    break
        
        return list(set(significant))  # Remove duplicates
    
    def _has_recent_adr(self, days: int = 7) -> bool:
        """
        Check if an ADR was created recently
        """
        if not self.adr_dir.exists():
            return False
        
        # Get most recent ADR
        adrs = sorted(self.adr_dir.glob("*.md"), key=lambda x: x.stat().st_mtime)
        
        if not adrs:
            return False
        
        most_recent = adrs[-1]
        age_days = (datetime.now() - datetime.fromtimestamp(most_recent.stat().st_mtime)).days
        
        return age_days < days
    
    def _generate_adr_suggestion(self, context: Dict, score: int) -> Dict:
        """
        Generate ADR suggestion based on context
        """
        file_path = context.get('file_path', '')
        description = context.get('description', '')
        
        # Determine decision type
        decision_type = self._classify_decision(description)
        
        # Generate title
        title = self._suggest_adr_title(description)
        
        # Generate context
        adr_context = f"""
The team has made a decision to {description.lower()}.
This change affects {file_path} and related components.
Decision significance score: {score}/10
        """.strip()
        
        # Generate consequences
        consequences = self._predict_consequences(decision_type, context)
        
        return {
            'title': title,
            'type': decision_type,
            'context': adr_context,
            'consequences': consequences,
            'tags': self._generate_tags(decision_type, file_path),
            'command': f'./scripts/create-adr.sh "{title}"'
        }
    
    def _classify_decision(self, description: str) -> str:
        """
        Classify the type of architectural decision
        """
        description_lower = description.lower()
        
        if any(word in description_lower for word in ['test', 'tdd', 'coverage']):
            return 'testing'
        elif any(word in description_lower for word in ['docker', 'container', 'kubernetes']):
            return 'infrastructure'
        elif any(word in description_lower for word in ['api', 'rest', 'graphql', 'grpc']):
            return 'api'
        elif any(word in description_lower for word in ['database', 'migration', 'schema']):
            return 'data'
        elif any(word in description_lower for word in ['security', 'auth', 'encryption']):
            return 'security'
        elif any(word in description_lower for word in ['performance', 'cache', 'optimize']):
            return 'performance'
        else:
            return 'architecture'
    
    def _suggest_adr_title(self, description: str) -> str:
        """
        Generate ADR title from description
        """
        # Clean up the description
        title = re.sub(r'[^\w\s-]', '', description)
        title = re.sub(r'\s+', ' ', title).strip()
        
        # Capitalize first letter of each word
        title = ' '.join(word.capitalize() for word in title.split())
        
        # Limit length
        if len(title) > 50:
            title = title[:47] + "..."
        
        return title
    
    def _predict_consequences(self, decision_type: str, context: Dict) -> Dict:
        """
        Predict positive and negative consequences
        """
        consequences_map = {
            'testing': {
                'positive': [
                    'Higher code quality',
                    'Fewer bugs in production',
                    'Better documentation through tests'
                ],
                'negative': [
                    'Slower initial development',
                    'Test maintenance overhead'
                ]
            },
            'infrastructure': {
                'positive': [
                    'Better scalability',
                    'Consistent environments',
                    'Easier deployment'
                ],
                'negative': [
                    'Additional complexity',
                    'Learning curve for team'
                ]
            },
            'api': {
                'positive': [
                    'Clear contracts',
                    'Better integration',
                    'Versioning support'
                ],
                'negative': [
                    'Breaking changes risk',
                    'Client update requirements'
                ]
            }
        }
        
        return consequences_map.get(decision_type, {
            'positive': ['Improved architecture'],
            'negative': ['Migration effort required']
        })
    
    def _generate_tags(self, decision_type: str, file_path: str) -> List[str]:
        """
        Generate relevant tags for the ADR
        """
        tags = [decision_type]
        
        # Add technology-specific tags
        if 'docker' in file_path.lower():
            tags.append('docker')
        if 'test' in file_path.lower():
            tags.append('testing')
        if '.py' in file_path:
            tags.append('python')
        if '.js' in file_path or '.ts' in file_path:
            tags.append('javascript')
        
        return tags
    
    def auto_generate_adr(self, title: str, context: str, decision: str, 
                         consequences: Dict, tags: List[str]) -> str:
        """
        Automatically generate an ADR file
        """
        # Ensure ADR directory exists
        self.adr_dir.mkdir(parents=True, exist_ok=True)
        
        # Get next ADR number
        existing_adrs = list(self.adr_dir.glob("[0-9]*.md"))
        next_number = len(existing_adrs) + 1
        
        # Generate filename
        filename_title = re.sub(r'[^\w\s-]', '', title).lower().replace(' ', '-')
        filename = self.adr_dir / f"{next_number:04d}-{filename_title}.md"
        
        # Generate content
        content = f"""# ADR-{next_number:04d}: {title}

Date: {datetime.now().strftime('%Y-%m-%d')}
Status: Proposed
Deciders: Development Team
Tags: {', '.join(tags)}

## Context

{context}

## Decision

{decision}

## Consequences

### Positive
{chr(10).join('- ' + c for c in consequences.get('positive', []))}

### Negative
{chr(10).join('- ' + c for c in consequences.get('negative', []))}

## Implementation

To be determined during implementation phase.

## Validation

Success metrics will be defined and tracked.

---
*Generated automatically by ADR Tracker*
"""
        
        # Write file
        filename.write_text(content)
        
        return str(filename)


# Hook registration
def register_hooks():
    """Register ADR tracking hooks with Claude Code"""
    tracker = ADRTracker()
    
    return {
        'post_code_generation': tracker.hook_post_code_generation,
        'pre_commit': tracker.hook_pre_commit
    }


# CLI interface
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "check":
            tracker = ADRTracker()
            if tracker._has_recent_adr():
                print("✅ Recent ADR found")
            else:
                print("⚠️  No recent ADR - consider documenting recent decisions")
        
        elif sys.argv[1] == "suggest":
            # Analyze recent commits for ADR opportunities
            result = subprocess.run(
                ["git", "log", "--oneline", "-10"],
                capture_output=True,
                text=True
            )
            
            tracker = ADRTracker()
            for line in result.stdout.split('\n'):
                if line:
                    score = tracker._calculate_decision_score("", line)
                    if score >= 3:
                        print(f"Potential ADR: {line} (score: {score})")
    else:
        print("Usage: adr-tracker.py [check|suggest]")