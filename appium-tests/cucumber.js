/**
 * Cucumber.js Configuration
 *
 * Reports generated:
 * - progress-bar: Console progress indicator
 * - html: Standard Cucumber HTML report (reports/cucumber-report.html)
 * - json: JSON report for other tools (reports/cucumber-report.json)
 * - junit: JUnit XML for CI/CD (reports/cucumber-report.xml)
 * - allure-cucumberjs: Allure report data (allure-results/)
 */
module.exports = {
    default: {
        requireModule: ['ts-node/register'],
        require: ['step-definitions/**/*.ts'],
        tags: 'not @skip',
        format: [
            'progress-bar',
            'html:reports/cucumber-report.html',
            'json:reports/cucumber-report.json',
            'junit:reports/cucumber-report.xml',
            './allure-formatter.js'
        ],
        formatOptions: {
            snippetInterface: 'async-await'
        }
    }
};
