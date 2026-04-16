"use strict";

module.exports = {
	public: false,

	port: 9000,

	// Limit memory usage — single user, limited resources
	maxHistory: 200,

	// SQLite only — no need for duplicate text logs
	messageStorage: ["sqlite"],

	// Enable link previews
	prefetch: true,
	prefetchMaxImageSize: 2048,
	disableMediaPreview: false,

	// No file uploads — soju HTTP listener not configured
	fileUpload: {
		enable: false,
	},

	reverseProxy: true,

	https: {
		enable: false,
	},

	theme: "default",

	// Pre-fill soju connection (internal Docker network, no TLS needed)
	defaults: {
		name: "soju",
		host: "soju",
		port: 6667,
		tls: false,
		rejectUnauthorized: false, // moot with tls: false, kept as safety net if TLS is ever enabled
		nick: "",
		username: "",
		password: "",
		realname: "",
		join: "",
	},
};
