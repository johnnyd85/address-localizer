import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCaseCount  from '@salesforce/apex/AddressLocalizerController.getCaseCount';
import relocateCases from '@salesforce/apex/AddressLocalizerController.relocateCases';

export default class AddressLocalizer extends LightningElement {

    @api   label         = 'Address Localizer';
    @track city           = '';
    @track state          = '';
    @track isLoading      = false;
    @track previewMessage = '';
    @track errorMessage   = '';
    @track successMessage = '';

    // ── Input handlers ──────────────────────────────────────────────────────

    handleCityChange(event) {
        this.city           = event.target.value;
        this.previewMessage = '';
        this.successMessage = '';
        this.errorMessage   = '';
    }

    handleStateChange(event) {
        this.state          = event.target.value.toUpperCase();
        this.previewMessage = '';
        this.successMessage = '';
        this.errorMessage   = '';
    }

    // ── Button state ────────────────────────────────────────────────────────

    get isPreviewDisabled() {
        return this.isLoading || !this.hasValidInputs;
    }

    get isRelocateDisabled() {
        return this.isLoading || !this.hasValidInputs;
    }

    get hasValidInputs() {
        return this.city.trim().length > 0 && this.state.trim().length === 2;
    }

    // ── Preview ─────────────────────────────────────────────────────────────

    handlePreview() {
        this.clearMessages();
        this.isLoading = true;

        getCaseCount()
            .then(count => {
                this.previewMessage = count > 0
                    ? `${count} 311 Case${count === 1 ? '' : 's'} will have their location set within a 5-mile radius of ${this.city}, ${this.state}.`
                    : 'No Cases with the 311 record type were found in this org.';
            })
            .catch(error => {
                this.errorMessage = this.extractError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ── Relocate ─────────────────────────────────────────────────────────────

    handleRelocate() {
        if (!this.hasValidInputs) return;

        this.clearMessages();
        this.isLoading = true;

        relocateCases({ city: this.city, state: this.state })
            .then(result => {
                if (result.success) {
                    const msg = `${result.updatedCount} 311 Case${result.updatedCount === 1 ? '' : 's'} successfully geolocated within 5 miles of ${result.targetCity}, ${result.targetState}.`;
                    this.successMessage = msg;
                    if (result.errorMessage) {
                        // Partial success — also surface the warning
                        this.errorMessage = result.errorMessage;
                    }
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title:   'Cases Geolocated',
                            message: msg,
                            variant: 'success'
                        })
                    );
                } else {
                    this.errorMessage = result.errorMessage || 'An unknown error occurred.';
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title:   'Relocation Failed',
                            message: this.errorMessage,
                            variant: 'error',
                            mode:    'sticky'
                        })
                    );
                }
            })
            .catch(error => {
                this.errorMessage = this.extractError(error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title:   'Relocation Failed',
                        message: this.errorMessage,
                        variant: 'error',
                        mode:    'sticky'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    clearMessages() {
        this.errorMessage   = '';
        this.successMessage = '';
        this.previewMessage = '';
    }

    extractError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}
