/**
 * Enhanced Agent Client for Persistence Service
 * Provides file saving capabilities with spec validation and TDD tracking
 */

class AgentPersistenceClient {
    constructor(config = {}) {
        this.baseUrl = config.baseUrl || 'http://localhost:5001';
        this.agentName = config.agentName || 'unknown-agent';
        this.specName = config.specName || null;
        this.tddPhase = config.tddPhase || 'implementation';
    }

    /**
     * Save a file with metadata and validation
     * @param {string} filename - Path to save the file
     * @param {string} content - File content
     * @param {Object} options - Additional options
     * @returns {Promise} - Result of save operation
     */
    async saveFile(filename, content, options = {}) {
        const metadata = {
            agent: this.agentName,
            spec_name: options.specName || this.specName,
            tdd_phase: options.tddPhase || this.tddPhase,
            timestamp: new Date().toISOString(),
            ...options.metadata
        };

        try {
            const response = await fetch(`${this.baseUrl}/save`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    filename,
                    content,
                    metadata
                }),
            });

            const data = await response.json();
            
            if (!response.ok) {
                console.error(`Failed to save ${filename}:`, data);
                return { success: false, ...data };
            }

            console.log(`✅ Saved: ${filename} (${data.status})`);
            return { success: true, ...data };
        } catch (error) {
            console.error(`Error saving ${filename}:`, error);
            return { 
                success: false, 
                status: 'error', 
                message: error.message 
            };
        }
    }

    /**
     * Save multiple files in batch
     * @param {Array} files - Array of {filename, content} objects
     * @param {Object} options - Additional options
     * @returns {Promise} - Results of all save operations
     */
    async saveFiles(files, options = {}) {
        const results = [];
        for (const file of files) {
            const result = await this.saveFile(
                file.filename, 
                file.content, 
                options
            );
            results.push(result);
        }
        return results;
    }

    /**
     * Validate content against specification
     * @param {string} filename - File path
     * @param {string} content - File content to validate
     * @param {string} specName - Specification name
     * @returns {Promise} - Validation result
     */
    async validateContent(filename, content, specName) {
        try {
            const response = await fetch(`${this.baseUrl}/validate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    filename,
                    content,
                    spec_name: specName || this.specName
                }),
            });

            return await response.json();
        } catch (error) {
            console.error('Validation error:', error);
            return { 
                valid: false, 
                errors: ['Validation service unavailable'] 
            };
        }
    }

    /**
     * Get list of available specifications
     * @returns {Promise} - List of specifications
     */
    async getSpecs() {
        try {
            const response = await fetch(`${this.baseUrl}/specs`);
            return await response.json();
        } catch (error) {
            console.error('Failed to fetch specs:', error);
            return [];
        }
    }

    /**
     * Helper function for TDD workflow
     * Ensures tests are saved before implementation
     */
    async saveTDDTest(filename, content, options = {}) {
        return this.saveFile(filename, content, {
            ...options,
            tddPhase: 'red',
            metadata: {
                ...options.metadata,
                fileType: 'test'
            }
        });
    }

    async saveTDDImplementation(filename, content, options = {}) {
        return this.saveFile(filename, content, {
            ...options,
            tddPhase: 'green',
            metadata: {
                ...options.metadata,
                fileType: 'implementation'
            }
        });
    }

    async saveTDDRefactored(filename, content, options = {}) {
        return this.saveFile(filename, content, {
            ...options,
            tddPhase: 'refactor',
            metadata: {
                ...options.metadata,
                fileType: 'refactored'
            }
        });
    }
}

// Simplified function for backward compatibility with Claude file-saver
function saveFile(filename, content) {
    const client = new AgentPersistenceClient();
    return client.saveFile(filename, content);
}

// Export for use in different contexts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { AgentPersistenceClient, saveFile };
}