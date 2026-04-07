import { LightningElement,wire } from 'lwc';

import {loadScript ,loadStyle } from 'lightning/platformResourceLoader';

import getRegions from '@salesforce/apex/NewsFeedController.getRegions';

import leaflet from '@salesforce/resourceUrl/leaflet' 
export default class CrisisMap extends LightningElement {
     regions = [];
     map;

     // addMarkers() is called from both renderedCallback and wire handler
     // to handle race condition — whichever finishes last will successfully
     // add markers only when both map and regions data are ready
     addMarkers() {
          if(this.map && this.regions.length > 0) {
               this.regions.forEach(region => {
                    L.marker([region.Latitude__c, region.Longitude__c])
                    .bindPopup(`${region.Name} - ${region.Threat_Level__c}`)
                    .addTo(this.map);
               });
          }
}
     
     @wire(getRegions)
     regionData({data,error}){
          if(data){
               this.regions = data
               if(this.map){
                    this.addMarkers();
               }
               
          }if(error){
               console.log(`Errors = ${error}`)
          }
     }



     mapInitialized = false;//flag act as a guard so theat map only initializes once even if rendercallBack Fires multiple times 

     async renderedCallback(){
          if (this.mapInitialized == true){
               return

          }else{

               this.mapInitialized = true;

               //load leaflet CSS and JS simultaneously from static resource
               await Promise.all([loadStyle(this,leaflet + '/leaflet/leaflet.css'),loadScript(this,leaflet + '/leaflet/leaflet.js')])

               //grab the map container div from HTML using lwc:ref
               let mapContainer = this.refs.mapContainer

               //create map inside the div and center it on Middle East
               this.map = L.map(mapContainer, {
                    scrollWheelZoom: false,
                    dragging: true,
                    zoomControl: true
                    }).setView([29.0, 53.0], 4);

               //add OpenStreetMap tile layer to paint world map imagery
               L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', { attribution: '© CartoDB' }).addTo(this.map)

               this.addMarkers();

          }
     }

}