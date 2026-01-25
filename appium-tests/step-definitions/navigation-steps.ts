import { When } from '@cucumber/cucumber';

/**
 * Step definitions for navigation scenarios
 * Note: add word button step moved to word-management-steps.ts
 */

When('I close the dialog', async function(this: any) {
    await this.driver.back();
});
