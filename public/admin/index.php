<?php
// Fallback entry point for Apache deployments where .htaccess overrides are unavailable.
// The front controller uses REQUEST_URI, so /admin and /admin/ are routed normally.
require __DIR__ . '/../index.php';
