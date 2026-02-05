/**
 * Wrapper for Allure Cucumber formatter
 * Creates a properly configured AllureRuntime and passes it to the formatter
 */
const { CucumberJSAllureFormatter } = require('allure-cucumberjs');
const { AllureRuntime } = require('allure-js-commons');
const path = require('path');

class AllureFormatterWrapper extends CucumberJSAllureFormatter {
    constructor(options) {
        const allureRuntime = new AllureRuntime({
            resultsDir: path.join(__dirname, 'allure-results'),
        });

        const config = {
            labels: [],
            links: [],
        };

        super(options, allureRuntime, config);
    }
}

module.exports = AllureFormatterWrapper;
