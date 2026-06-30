import { LightningElement } from 'lwc';
import createRegion from '@salesforce/apex/NewsFeedController.createRegion';
import fetchNewsForRegion from '@salesforce/apex/NewsFeedController.fetchNewsForRegion';
import lookupRegion from '@salesforce/apex/NewsFeedController.lookupRegion';

export default class AddRegionModal extends LightningElement {

    // form field values
    name = '';
    latitude = null;
    longitude = null;
    threatLevel = '';
    searchQuery = '';
    isLoading = false; // shows loading state while lookup runs

    

    // handle each input change
    handleName(event) { this.name = event.target.value; }
    handleLatitude(event) { this.latitude = parseFloat(event.target.value); }
    handleLongitude(event) { this.longitude = parseFloat(event.target.value); }
    handleThreatLevel(event) { this.threatLevel = event.target.value; }
    handleSearchQuery(event) { this.searchQuery = event.target.value; }

    // cancel button — fire event to parent to close modal
    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    // add button — call Apex to create region then immediately fetch news
    handleAdd() {
        if(!this.name || !this.latitude || !this.longitude || !this.threatLevel) {
            alert('Please fill in all required fields');
            return;
        }

        createRegion({
            name: this.name,
            latitude: this.latitude,
            longitude: this.longitude,
            threatLevel: this.threatLevel,
            searchQuery: this.searchQuery
        })
        .then(() => {
            // immediately fetch news for new region — no waiting for scheduler
            return fetchNewsForRegion({ regionName: this.name });
        })
        .then(() => {
            // notify parent region was added successfully
            this.dispatchEvent(new CustomEvent('regionadded'));
        })
        .catch(error => {
            console.log('Error creating region: ' + error);
        });
    }

    handleLookup() {
    if(!this.name) {
        alert('Please enter a region name first');
        return;
     }

        this.isLoading = true;
        
        lookupRegion({ regionName: this.name })
        .then(result => {
            this.isLoading = false;
            if(result.latitude) {
                this.latitude = parseFloat(result.latitude);
                this.longitude = parseFloat(result.longitude);
            }
            if(result.threatLevel) {
                this.threatLevel = result.threatLevel;
            }
            if(result.searchQuery) {
                this.searchQuery = result.searchQuery;
            }
        })
        .catch(error => {
            this.isLoading = false;
            console.log('Lookup error: ' + error);
        });
    }

    get lookupLabel() {
    return this.isLoading ? 'LOOKING UP...' : 'LOOKUP';
    }
}