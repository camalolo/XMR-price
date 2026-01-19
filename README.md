# XMR Price Chrome Extension

A simple Chrome extension that displays the current Monero price in USD directly on the extension icon.

## Features

- **Real-time Price Display**: Shows the current Monero price in USD on the extension badge
- **Automatic Updates**: Refreshes price data every 30 minutes
- **Manual Refresh**: Click the extension icon to force an immediate update
- **Error Handling**: Displays error status if API is unavailable
- **Caching**: Stores price data locally to minimize API calls

## Installation

1. Download or clone this repository
2. Open Chrome and navigate to `chrome://extensions/`
3. Enable "Developer mode" in the top right corner
4. Click "Load unpacked" and select the extension directory
5. The XMR Price extension should now appear in your extensions list

## Usage

- The extension icon will display the current Monero price (in USD)
- Click the icon to manually refresh the price data
- Price data updates automatically every 30 minutes

## API

This extension uses the [CoinGecko Simple Price API](https://www.coingecko.com/en/api/documentation) to fetch current Monero price in USD.

## Permissions

- **Storage**: To cache price data locally
- **Alarms**: To schedule periodic updates
- **Host Permissions**: Access to `https://api.coingecko.com/*` for API calls

## Files

- `manifest.json`: Extension manifest file
- `background.js`: Service worker handling price fetching and badge updates
- `icon16.png`, `icon48.png`, `icon128.png`: Extension icons

## Development

To modify the extension:

1. Make changes to the source files
2. Reload the extension in `chrome://extensions/`
3. Test the changes

## License

MIT License - feel free to use and modify as needed.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.