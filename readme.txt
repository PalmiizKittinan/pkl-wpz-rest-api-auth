=== PKL WPz REST API Authentication ===
Contributors: kittlam
Tags: rest-api, authentication, api-key, security
Requires at least: 5.0
Tested up to: 7.1
Requires PHP: 7.4
Stable tag: 1.2.1
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Control WordPress REST API access by requiring user authentication with API key system.

== Description ==

PKL WPz REST API Authentication provides a simple way to authenticate WordPress REST API requests using API keys. Users can generate their own API keys from their profile page and use them to make authenticated API requests.

Features:

* User-friendly API key generation from profile page
* Secure API key storage with WordPress security standards
* Easy integration with WordPress REST API
* Support for Bearer token authentication
* API key revocation capability
* Admin can manage all users' API keys
* Bearer token is the only supported authentication method

== Installation ==

1. Upload the plugin files to the `/wp-content/plugins/pkl-wpz-rest-api-auth` directory, or install the plugin through the WordPress plugins screen directly.
2. Activate the plugin through the 'Plugins' screen in WordPress.
3. Users can generate API keys from their profile page (Users > Your Profile).
4. Use the generated API key in the Authorization header: `Authorization: Bearer YOUR_API_KEY`

== Frequently Asked Questions ==

= How do I generate an API key? =

1. Go to Users > Your Profile in WordPress admin
2. Scroll down to the "REST API Access" section
3. Click "Generate New API Key"
4. Copy and save your API key securely

= How do I use the API key? =

Send it as a Bearer token in the Authorization header (the only supported method): `Authorization: Bearer YOUR_API_KEY`

= Can I revoke an API key? =

Yes, you can revoke your API key from your profile page by clicking the "Revoke API Key" button.

= Is it secure? =

Yes, the plugin follows WordPress security best practices and stores API keys securely in the database.

== Changelog ==

= Unreleased =
Bearer token is now the only supported authentication method. X-API-Key header, form-data and query parameter removed.

= 1.2.1 =
Confirm compatibility with WordPress 7.1

= 1.2.0 =
Add WordPress 7.x compatibility

= 1.1.0 =
Change database table schema _id -> UUID()

= 1.0.0 =
Plugin Launch

== Developer Documentation ==

For detailed API documentation and examples, visit the plugin settings page in your WordPress admin.

== Support ==

For support and feature requests, please visit our GitHub repository [@PalmiizKittinan](https://github.com/PalmiizKittinan) .