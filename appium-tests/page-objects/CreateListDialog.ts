import { BasePage } from './BasePage';
import { Browser } from 'webdriverio';

interface CreateListDialogKeys {
    nameField: string;
    createButton: string;
}

/**
 * Create List Dialog Page Object
 * Represents the dialog for creating a new vocabulary list
 */
export class CreateListDialog extends BasePage {
    private keys: CreateListDialogKeys;
    private dialogTitle: string;
    private cancelButtonText: string;

    constructor(driver: Browser) {
        super(driver);

        // Flutter Keys
        this.keys = {
            nameField: 'list_name_field',
            createButton: 'create_list_button'
        };

        // Text selectors (for elements without Keys)
        this.dialogTitle = 'Nouvelle liste';
        this.cancelButtonText = 'Annuler';
    }

    /**
     * Verify dialog is displayed
     */
    async isDisplayed(): Promise<boolean> {
        return await this.elementExistsByText(this.dialogTitle);
    }

    /**
     * Wait for dialog to appear
     */
    async waitForDialog(): Promise<void> {
        await this.waitForText(this.dialogTitle);
        await this.pause(500);
    }

    /**
     * Enter list name
     */
    async enterListName(name: string): Promise<void> {
        await this.enterTextByKey(this.keys.nameField, name);
    }

    /**
     * Click create button
     */
    async clickCreate(): Promise<void> {
        await this.clickByKey(this.keys.createButton);
        await this.pause(2000);
    }

    /**
     * Click cancel button
     */
    async clickCancel(): Promise<void> {
        await this.clickByText(this.cancelButtonText);
        await this.pause(500);
    }

    /**
     * Create a simple list with just a name
     */
    async createSimpleList(name: string, _description?: string): Promise<void> {
        await this.waitForDialog();
        await this.enterListName(name);
        await this.clickCreate();
    }
}
