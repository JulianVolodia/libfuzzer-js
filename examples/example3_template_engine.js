// Example 3: Template Engine - Fuzzing Template Processing
// This demonstrates fuzzing a simple template rendering engine

// ============================================
// YOUR CODE (the target to fuzz)
// ============================================

class TemplateEngine {
    constructor() {
        this.helpers = {};
    }

    registerHelper(name, fn) {
        this.helpers[name] = fn;
    }

    render(template, data) {
        let result = template;

        // Replace {{variable}} with data
        result = result.replace(/\{\{([a-zA-Z0-9_.]+)\}\}/g, (match, path) => {
            return this.getNestedValue(data, path) || '';
        });

        // Execute helpers: {{helper:arg}}
        result = result.replace(/\{\{([a-zA-Z0-9]+):([^}]+)\}\}/g, (match, helperName, arg) => {
            const helper = this.helpers[helperName];
            if (helper) {
                try {
                    return helper(arg);
                } catch (e) {
                    return `[Error: ${e.message}]`;
                }
            }
            return match;
        });

        // Execute loops: {{#each array}}...{{/each}}
        result = result.replace(
            /\{\{#each\s+([a-zA-Z0-9_.]+)\}\}(.*?)\{\{\/each\}\}/gs,
            (match, path, loopBody) => {
                const array = this.getNestedValue(data, path);
                if (!Array.isArray(array)) return '';

                // BUG: No limit on loop iterations!
                // Could cause performance issues or stack overflow
                return array.map((item, index) => {
                    let itemResult = loopBody;
                    itemResult = itemResult.replace(/\{\{this\}\}/g, item);
                    itemResult = itemResult.replace(/\{\{@index\}\}/g, index);
                    return itemResult;
                }).join('');
            }
        );

        // Execute conditionals: {{#if condition}}...{{/if}}
        result = result.replace(
            /\{\{#if\s+([a-zA-Z0-9_.]+)\}\}(.*?)\{\{\/if\}\}/gs,
            (match, path, ifBody) => {
                const value = this.getNestedValue(data, path);
                // BUG: Doesn't handle else clause
                return value ? ifBody : '';
            }
        );

        return result;
    }

    getNestedValue(obj, path) {
        const parts = path.split('.');
        let current = obj;

        for (const part of parts) {
            if (current === null || current === undefined) {
                return undefined;
            }
            // BUG: No protection against prototype pollution!
            // Accessing __proto__ or constructor could be dangerous
            current = current[part];
        }

        return current;
    }
}

// Create engine and register helpers
const engine = new TemplateEngine();

engine.registerHelper('upper', (str) => {
    return String(str).toUpperCase();
});

engine.registerHelper('lower', (str) => {
    return String(str).toLowerCase();
});

engine.registerHelper('repeat', (str) => {
    const times = parseInt(str.split(',')[1]) || 1;
    const text = str.split(',')[0];

    // BUG: No limit on repetitions!
    // Could cause memory exhaustion
    return text.repeat(times);
});

// ============================================
// FUZZING HARNESS
// ============================================

function fuzzTemplateEngine(input) {
    if (!input || input.length < 10) return;

    try {
        // Use first byte to select fuzzing strategy
        const strategy = input[0] % 4;

        switch (strategy) {
            case 0:
                // Fuzz variable substitution
                fuzzVariableSubstitution(input.slice(1));
                break;

            case 1:
                // Fuzz helpers
                fuzzHelpers(input.slice(1));
                break;

            case 2:
                // Fuzz loops
                fuzzLoops(input.slice(1));
                break;

            case 3:
                // Fuzz nested structures
                fuzzNestedStructures(input.slice(1));
                break;
        }

    } catch (e) {
        // Expected errors for malformed templates
    }
}

function fuzzVariableSubstitution(input) {
    const template = String.fromCharCode.apply(null, input.slice(0, 100));

    const data = {
        name: String.fromCharCode.apply(null, input.slice(100, 120)),
        value: (input[0] << 8) | input[1],
        nested: {
            deep: {
                value: String.fromCharCode.apply(null, input.slice(120, 140))
            }
        },
        // Test prototype pollution
        __proto__: { polluted: 'dangerous' },
        constructor: { dangerous: true }
    };

    engine.render(template, data);
}

function fuzzHelpers(input) {
    const helperName = ['upper', 'lower', 'repeat'][input[0] % 3];
    const arg = String.fromCharCode.apply(null, input.slice(1, 50));

    const template = `{{${helperName}:${arg}}}`;

    engine.render(template, {});
}

function fuzzLoops(input) {
    // Create array with length from fuzzer
    const arrayLength = Math.min(input[0], 100);  // Limit to prevent OOM
    const items = Array.from({ length: arrayLength }, (_, i) =>
        String.fromCharCode(input[i + 1] || 65)
    );

    const template = `{{#each items}}{{this}} {{/each}}`;

    engine.render(template, { items });

    // Test with very large array (will expose performance bug)
    if (input.length > 10) {
        const largeItems = new Array(10000).fill('x');
        const largeTemplate = `{{#each large}}{{this}}{{/each}}`;

        // This could hang or crash!
        engine.render(largeTemplate, { large: largeItems });
    }
}

function fuzzNestedStructures(input) {
    const template = String.fromCharCode.apply(null, input);

    const data = {
        users: [
            { name: 'Alice', active: true },
            { name: 'Bob', active: false },
            { name: String.fromCharCode.apply(null, input.slice(0, 10)) }
        ],
        config: {
            theme: 'dark',
            nested: {
                deep: {
                    value: 'test'
                }
            }
        }
    };

    engine.render(template, data);
}

// Fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    fuzzTemplateEngine(FuzzerInput);
}

/*
 * HOW TO RUN THIS EXAMPLE:
 *
 * 1. Save this file as example3_template_engine.js
 *
 * 2. Run the fuzzer:
 *    ./jsfuzzer --js=examples/example3_template_engine.js -max_len=500 -timeout=10
 *
 * 3. Increase timeout to detect performance issues:
 *    ./jsfuzzer --js=examples/example3_template_engine.js -timeout=25
 *
 * EXPECTED BUGS:
 * - No limit on loop iterations (performance issue)
 * - No limit on repeat helper (memory exhaustion)
 * - Prototype pollution via getNestedValue
 * - ReDoS in regex patterns
 */
