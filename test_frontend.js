const { chromium } = require('playwright');
const path = require('path');

(async () => {
  console.log('Skipping frontend verification since this is a mobile app and playwright only works for web apps.');
})();
