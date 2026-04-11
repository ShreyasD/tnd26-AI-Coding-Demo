import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import searchProperties from '@salesforce/apex/LeadHouseCaptureController.searchProperties';
import createLeadsForProperties from '@salesforce/apex/LeadHouseCaptureController.createLeadsForProperties';
import getDistinctStylesFromTags from '@salesforce/apex/LeadHouseCaptureController.getDistinctStylesFromTags';

export default class LeadHouseCapture extends LightningElement {
    // Form inputs
    cityOrState = '';
    minBedrooms = 0;
    selectedStyle = '';
    minPrice = null;
    maxPrice = null;

    // Derived options
    @track styleOptions = [{ label: 'Any', value: '' }];

    // Results and state
    @track properties = [];
    @track selectedMap = new Map(); // propertyId -> true
    isSearching = false;
    hasSearched = false;

    connectedCallback() {
        this.loadStyleOptions();
    }

    async loadStyleOptions() {
        try {
            const styles = await getDistinctStylesFromTags();
            const opts = [{ label: 'Any', value: '' }];
            if (styles && Array.isArray(styles)) {
                styles.forEach((s) => {
                    if (s) {
                        opts.push({ label: s, value: s });
                    }
                });
            }
            this.styleOptions = opts;
        } catch (e) {
            this.toast('Could not load style options', this.errorMessage(e), 'error');
        }
    }

    // Handlers for inputs
    handleCityStateChange = (e) => {
        this.cityOrState = e.target.value;
    };
    handleBedroomsChange = (e) => {
        const val = Number(e.target.value);
        this.minBedrooms = isNaN(val) || val < 0 ? 0 : val;
    };
    handleStyleChange = (e) => {
        this.selectedStyle = e.detail.value || '';
    };
    handleMinPriceChange = (e) => {
        const val = e.target.value;
        this.minPrice = val === '' || val === null ? null : Number(val);
    };
    handleMaxPriceChange = (e) => {
        const val = e.target.value;
        this.maxPrice = val === '' || val === null ? null : Number(val);
    };

    // Helper to compute displayTags safely (comma-separated string)
    computeDisplayTags(p) {
        if (!p || !p.tags) return '';
        try {
            // Ensure it's an array of strings
            const arr = Array.isArray(p.tags) ? p.tags : [];
            return arr.filter((t) => typeof t === 'string' && t.trim().length).join(', ');
        } catch (e) {
            return '';
        }
    }

    // Search logic
    async handleSearch() {
        // Basic validation: if both min and max present, ensure min <= max
        if (this.minPrice !== null && this.maxPrice !== null && Number(this.minPrice) > Number(this.maxPrice)) {
            this.toast('Invalid price range', 'Min Price must be less than or equal to Max Price.', 'warning');
            return;
        }
        this.isSearching = true;
        this.hasSearched = true;
        try {
            const results = await searchProperties({
                cityOrState: (this.cityOrState || '').trim(),
                minBedrooms: this.minBedrooms,
                style: this.selectedStyle || '',
                minPrice: this.minPrice,
                maxPrice: this.maxPrice
            });
            // Map into UI models and preserve selection state; compute displayTags
            const sel = this.selectedMap;
            this.properties = (results || []).map((p) => {
                const selected = sel.has(p.id);
                const displayTags = this.computeDisplayTags(p);
                // compute per-item disabled flag (cannot call methods from template)
                const selectDisabled = !selected && this.selectedCount >= 3;
                return {
                    ...p,
                    selected,
                    displayTags,
                    selectDisabled
                };
            });
        } catch (e) {
            this.toast('Search failed', this.errorMessage(e), 'error');
        } finally {
            this.isSearching = false;
        }
    }

    handleClear = () => {
        this.cityOrState = '';
        this.minBedrooms = 0;
        this.selectedStyle = '';
        this.minPrice = null;
        this.maxPrice = null;
        this.properties = [];
        this.selectedMap = new Map();
        this.hasSearched = false;
    };

    // Computed getter to control Submit button disabled state (replaces template expression)
    get isSubmitDisabled() {
        return this.selectedCount === 0;
    }

    // Selection logic
    toggleSelect = (e) => {
        const id = e.currentTarget.dataset.id;
        if (!id) return;

        const currentlySelected = this.selectedMap.has(id);
        if (currentlySelected) {
            this.selectedMap.delete(id);
        } else {
            if (this.selectedCount >= 3) {
                // enforce max 3
                this.toast('Selection limit', 'You can select up to 3 properties.', 'warning');
                return;
            }
            this.selectedMap.set(id, true);
        }

        // reflect in properties array and recompute per-item disabled flag
        const reachedMax = this.selectedCount >= 3;
        this.properties = this.properties.map((p) => {
            const isSelected = this.selectedMap.has(p.id);
            const selectDisabled = !isSelected && reachedMax;
            return p.id === id ? { ...p, selected: isSelected, selectDisabled } : { ...p, selectDisabled };
        });
    };

    // Getter to indicate whether "Select" should be disabled for the current item in loop.
    // Since template expressions can't call functions, expose a boolean on each item instead.
    isSelectDisabled = (propId) => {
        return !this.selectedMap.has(propId) && this.selectedCount >= 3;
    };

    get selectedCount() {
        return this.selectedMap.size;
    }

    // Submit
    async handleSubmit() {
        if (this.selectedCount === 0) {
            this.toast('No selection', 'Please select at least one property to submit.', 'info');
            return;
        }
        // Collect selected property Ids preserving display order
        const ids = this.properties.filter((p) => p.selected).map((p) => p.id).slice(0, 3);

        try {
            const res = await createLeadsForProperties({
                propertyIds: ids,
                cityOrState: (this.cityOrState || '').trim(),
                bedrooms: this.minBedrooms,
                style: this.selectedStyle || '',
                minPrice: this.minPrice,
                maxPrice: this.maxPrice
            });

            const successes = (res || []).filter((r) => r.success);
            if (successes.length > 0) {
                this.toast('Leads created', `Successfully created ${successes.length} lead(s).`, 'success');
            }
            const failures = (res || []).filter((r) => !r.success);
            if (failures.length > 0) {
                const msg = failures.map((f) => f.message || 'Failed').join('; ');
                this.toast('Some leads failed', msg, 'warning');
            }
        } catch (e) {
            this.toast('Submit failed', this.errorMessage(e), 'error');
        }
    }

    // Utilities
    toast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: variant || 'info',
            })
        );
    }

    errorMessage(e) {
        if (!e) return 'Unknown error';
        // Apex errors might be in body.message or body.pageErrors
        const body = e.body || {};
        if (typeof body.message === 'string') return body.message;
        if (Array.isArray(body.pageErrors) && body.pageErrors.length) return body.pageErrors[0].message;
        if (Array.isArray(e.body)) return e.body.map((er) => er.message).join(', ');
        return e.message || 'Unknown error';
    }
}