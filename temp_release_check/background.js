// Function to update the badge with price text
function updateBadge(priceText) {
  console.log('updateBadge called with priceText:', priceText);
  try {
    let shortPrice;
    if (priceText === 'Error') {
      shortPrice = 'Err';
    } else {
      const priceAmount = Number.parseFloat(priceText);
      // One-liner: Format based on magnitude, max 4 chars
      shortPrice = priceAmount.toFixed(priceAmount >= 100 ? 0 : (priceAmount >= 10 ? 1 : 2)).slice(0, 4);
    }

    chrome.action.setBadgeText({ text: shortPrice });
    chrome.action.setBadgeBackgroundColor({ color: '#222222' }); // Dark grey
    console.log('Badge updated with:', shortPrice);
  } catch (error) {
    console.error('Error updating badge:', error);
    chrome.action.setBadgeText({ text: 'Err' });
    chrome.action.setBadgeBackgroundColor({ color: '#FF0000' }); // Red for error
  }
}

// Rest of the code remains unchanged...
function fetchXMRPrice(forceUpdate = false) {
  console.log('fetchXMRPrice called');
  chrome.storage.local.get(['price', 'lastUpdate'], (result) => {
    console.log('Storage data retrieved:', result);

    const now = Date.now();
    const lastUpdate = result.lastUpdate || 0;
    console.log('Current time:', now, 'Last update:', lastUpdate);

    if ((now - lastUpdate > 30 * 60 * 1000) || forceUpdate) {
      console.log('Fetching new price from API');
      fetch('https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd')
        .then(response => {
          console.log('API response status:', response.status);
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          return response.json();
        })
        .then(data => {
          console.log('API response data:', data);
          const newPrice = data.monero.usd;
          console.log('New price (USD):', newPrice);
          chrome.storage.local.set({ price: newPrice, lastUpdate: now }, () => {
            console.log('Price and lastUpdate saved to storage');
          });
          updateBadge(newPrice);
        })
        .catch(error => {
          console.error('Fetch error:', error);
          if (error instanceof TypeError) {
            console.error('Failed to fetch. Retrying in 30 seconds');
            setTimeout(fetchXMRPrice, 30_000);
          } else {
            updateBadge('Error');
          }
        });
    } else if (result.price) {
      console.log('Using cached price:', result.price);
      updateBadge(result.price);
    } else {
      console.log('No cached price available');
      updateBadge('Error');
    }
  });
}

chrome.action.onClicked.addListener(() => {
  console.log('Icon clicked, refreshing XMR price');
  fetchXMRPrice(true);
});

console.log('Extension loaded, initiating first fetch');
fetchXMRPrice();

console.log('Creating alarm for periodic updates');
chrome.alarms.create('updateXMRPrice', { periodInMinutes: 30 });
chrome.alarms.onAlarm.addListener((alarm) => {
  console.log('Alarm triggered:', alarm.name);
  if (alarm.name === 'updateXMRPrice') {
    fetchXMRPrice();
  }
});