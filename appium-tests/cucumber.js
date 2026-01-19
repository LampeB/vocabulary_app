/**
 * Cucumber.js Configuration
 */
module.exports = {
    default: {
        requireModule: ['ts-node/register'],
        require: ['step-definitions/**/*.ts'],
        format: [
            'progress-bar',
            'html:reports/cucumber-report.html',
            'json:reports/cucumber-report.json',
            'junit:reports/cucumber-report.xml'
        ],
        formatOptions: {
            snippetInterface: 'async-await'
        },
        publishQuiet: true
    }
};
