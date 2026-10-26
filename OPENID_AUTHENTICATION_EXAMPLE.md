# OpenID Authentication in JupyterLab with npm oidc-provider

This guide shows how to authenticate JupyterLab using JupyterHub with the `oidc-provider` npm package as your identity provider.

## Installation

```bash
pip install jupyterhub oauthenticator
```

## Step 1: Configure JupyterHub to use your oidc-provider

```python
# jupyterhub_config.py
from oauthenticator.generic import GenericOAuthenticator
import os

c.JupyterHub.authenticator_class = GenericOAuthenticator

# Your oidc-provider endpoints
OIDC_BASE_URL = os.environ.get('OIDC_BASE_URL', 'http://localhost:3000/oidc')

c.GenericOAuthenticator.oauth_callback_url = os.environ.get(
    'JUPYTERHUB_OAUTH_CALLBACK_URL',
    'http://localhost:8000/hub/oauth_callback'
)

# Client credentials registered in your oidc-provider
c.GenericOAuthenticator.client_id = os.environ.get('OIDC_CLIENT_ID', 'default-client')
c.GenericOAuthenticator.client_secret = os.environ.get('OIDC_CLIENT_SECRET', 'default-secret')

# oidc-provider standard endpoints
# Note: Check your discovery document at {OIDC_BASE_URL}/.well-known/openid-configuration
# to get the exact endpoint URLs
c.GenericOAuthenticator.authorize_url = f'{OIDC_BASE_URL}/auth'
c.GenericOAuthenticator.token_url = f'{OIDC_BASE_URL}/token'
c.GenericOAuthenticator.userdata_url = f'{OIDC_BASE_URL}/me'  # oidc-provider uses /me for userinfo

# Username extraction from userinfo response
# oidc-provider typically returns 'sub' as the user identifier
# You can also use 'preferred_username' if you set it in claims
c.GenericOAuthenticator.username_key = 'sub'  # or 'preferred_username' if available

# Required scopes
c.GenericOAuthenticator.scope = ['openid', 'profile', 'email']

# Optional: Token validation
c.GenericOAuthenticator.token_url_params = {
    'grant_type': 'authorization_code'
}

# Optional: User whitelist
# c.Authenticator.allowed_users = {'user1', 'user2'}

# Optional: Admin users (based on username from oidc-provider)
c.Authenticator.admin_users = {'admin-user'}
```

## Step 2: Environment variables

Create a `.env` file or set environment variables:

```bash
# .env
OIDC_BASE_URL=http://localhost:3000/oidc
OIDC_CLIENT_ID=jupyterhub
OIDC_CLIENT_SECRET=your-client-secret-here
JUPYTERHUB_OAUTH_CALLBACK_URL=http://localhost:8000/hub/oauth_callback
```

## Step 3: Testing the setup

1. **Start your oidc-provider** (using your existing setup)

2. **Verify discovery document:**

```bash
curl http://localhost:3000/oidc/.well-known/openid-configuration
```

3. **Start JupyterHub:**

```bash
jupyterhub -f jupyterhub_config.py
```

4. **Access JupyterHub:**
   - Navigate to `http://localhost:8000`
   - You'll be redirected to your oidc-provider for authentication
   - After successful login, you'll be redirected back to JupyterHub

## Getting Access Token in Jupyter Notebook

To get an `access_token` from your oidc-provider in a Jupyter notebook, you can use either the **device flow** (recommended for notebooks) or the **authorization code flow**. Here are the approaches:

### Method 0: Device Flow (Recommended for Notebooks)

The device flow (RFC 8628) is ideal for notebooks as it doesn't require opening a browser or handling redirects. The user enters a code on a separate device/browser.

**Note:** Make sure device flow is enabled in your oidc-provider configuration (`features.deviceFlow.enabled = true`).

**Use it in your notebook:**

```python
# In your Jupyter notebook
import micropip
import time
from IPython.display import HTML, display

await micropip.install("requests")

import requests

# Configuration
OIDC_BASE_URL = "http://localhost:3000/oidc"
CLIENT_ID = "default-client"
CLIENT_SECRET = "default-secret"  # Required for confidential clients
SCOPE = "openid profile email"

# Step 1: Request device code
device_code_response = requests.post(
    f"{OIDC_BASE_URL}/device/auth",
    data={
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "scope": SCOPE,
    },
    headers={"Content-Type": "application/x-www-form-urlencoded"},
)

if device_code_response.status_code != 200:
    print(f"Error requesting device code: {device_code_response.status_code}")
    print(device_code_response.text)
else:
    device_data = device_code_response.json()
    device_code = device_data["device_code"]
    user_code = device_data["user_code"]
    verification_uri = device_data["verification_uri"]
    verification_uri_complete = device_data.get("verification_uri_complete")
    interval = device_data.get("interval", 5)  # Polling interval in seconds
    expires_in = device_data.get("expires_in", 600)  # Default 10 minutes
    
    # Step 2: Display user code and verification URI
    print("=" * 60)
    print("DEVICE FLOW AUTHENTICATION")
    print("=" * 60)
    print(f"\n1. Visit: {verification_uri}")
    if verification_uri_complete:
        print(f"   Or use this complete URL: {verification_uri_complete}")
    print(f"\n2. Enter this code: {user_code}")
    print(f"\n3. Waiting for authorization...")
    print("=" * 60)
    
    # Display as clickable link in notebook
    if verification_uri_complete:
        display(HTML(f'''
        <div style="padding: 20px; border: 2px solid #4CAF50; border-radius: 5px; background-color: #f0f8f0;">
            <h3>🔐 Device Flow Authentication</h3>
            <p><strong>Step 1:</strong> Click the link below or visit: <code>{verification_uri}</code></p>
            <p><a href="{verification_uri_complete}" target="_blank" style="font-size: 18px; padding: 10px 20px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px;">Open Authorization Page</a></p>
            <p><strong>Step 2:</strong> Enter this code: <code style="font-size: 24px; font-weight: bold; color: #2196F3;">{user_code}</code></p>
            <p><strong>Step 3:</strong> Wait for authorization...</p>
        </div>
        '''))
    else:
        display(HTML(f'''
        <div style="padding: 20px; border: 2px solid #4CAF50; border-radius: 5px; background-color: #f0f8f0;">
            <h3>🔐 Device Flow Authentication</h3>
            <p><strong>Step 1:</strong> Visit: <a href="{verification_uri}" target="_blank">{verification_uri}</a></p>
            <p><strong>Step 2:</strong> Enter this code: <code style="font-size: 24px; font-weight: bold; color: #2196F3;">{user_code}</code></p>
            <p><strong>Step 3:</strong> Wait for authorization...</p>
        </div>
        '''))
    
    # Step 3: Poll for token
    start_time = time.time()
    timeout = expires_in
    
    while time.time() - start_time < timeout:
        try:
            token_response = requests.post(
                f"{OIDC_BASE_URL}/token",
                data={
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "device_code": device_code,
                    "client_id": CLIENT_ID,
                    "client_secret": CLIENT_SECRET,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            
            if token_response.status_code == 200:
                token_data = token_response.json()
                access_token = token_data["access_token"]
                refresh_token = token_data.get("refresh_token")
                
                print("\n✓ Successfully authenticated!")
                print(f"Access Token: {access_token[:50]}...")
                print(f"Expires in: {token_data.get('expires_in', 'N/A')} seconds")
                
                # Store in environment
                import os
                os.environ['OIDC_ACCESS_TOKEN'] = access_token
                if refresh_token:
                    os.environ['OIDC_REFRESH_TOKEN'] = refresh_token
                
                # Display success message
                display(HTML('''
                <div style="padding: 20px; border: 2px solid #4CAF50; border-radius: 5px; background-color: #d4edda;">
                    <h3 style="color: #155724;">✓ Authentication Successful!</h3>
                    <p>Access token has been obtained and stored.</p>
                </div>
                '''))
                break
            else:
                # Handle error response
                error_data = token_response.json()
                error = error_data.get("error", "")
                error_description = error_data.get("error_description", "")
                error_msg = error_description or error or token_response.text
                
                # Check if it's an "authorization_pending" or "slow_down" error
                # Check both the error code and the error message/description
                if (
                    error == "authorization_pending" or
                    error == "slow_down" or
                    "authorization_pending" in error_msg.lower() or
                    "slow_down" in error_msg.lower() or
                    "authorization request is still pending" in error_msg.lower()
                ):
                    # Still waiting for user authorization - keep polling
                    if error == "slow_down":
                        interval += 5  # Increase polling interval
                    print(".", end="", flush=True)
                    time.sleep(interval)
                elif error == "expired_token":
                    print("\n✗ Device code expired. Please start over.")
                    break
                elif error == "access_denied":
                    print("\n✗ Access denied by user.")
                    break
                else:
                    print(f"\n✗ Error: {error_msg}")
                    break
        except Exception as e:
            print(f"\n✗ Unexpected error: {e}")
            break
    else:
        print("\n✗ Timeout waiting for authorization")
```

**Simplified version with better error handling:**

```python
# Simplified device flow function
async def get_access_token_device_flow(
    oidc_base_url="http://localhost:3000/oidc",
    client_id="default-client",
    client_secret="default-secret",
    scope="openid profile email"
):
    """Get access token using device flow"""
    import micropip
    import time
    from IPython.display import HTML, display

    await micropip.install("requests")

    import requests
    
    # Request device code
    device_response = requests.post(
        f"{oidc_base_url}/device/auth",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": scope,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    
    if device_response.status_code != 200:
        raise Exception(f"Failed to get device code: {device_response.text}")
    
    device_data = device_response.json()
    device_code = device_data["device_code"]
    user_code = device_data["user_code"]
    verification_uri = device_data["verification_uri"]
    verification_uri_complete = device_data.get("verification_uri_complete", verification_uri)
    interval = device_data.get("interval", 5)
    expires_in = device_data.get("expires_in", 600)
    
    # Display instructions
    display(HTML(f'''
    <div style="padding: 20px; border: 2px solid #4CAF50; border-radius: 5px; background-color: #f0f8f0;">
        <h3>🔐 Device Flow Authentication</h3>
        <p><a href="{verification_uri_complete}" target="_blank" style="font-size: 18px; padding: 10px 20px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px;">Open Authorization Page</a></p>
        <p><strong>Enter code:</strong> <code style="font-size: 24px; font-weight: bold; color: #2196F3;">{user_code}</code></p>
        <p>Waiting for authorization...</p>
    </div>
    '''))
    
    # Poll for token
    start_time = time.time()
    while time.time() - start_time < expires_in:
        try:
            token_response = requests.post(
                f"{oidc_base_url}/token",
                data={
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "device_code": device_code,
                    "client_id": client_id,
                    "client_secret": client_secret,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            
            if token_response.status_code == 200:
                token_data = token_response.json()
                import os
                os.environ['OIDC_ACCESS_TOKEN'] = token_data["access_token"]
                if "refresh_token" in token_data:
                    os.environ['OIDC_REFRESH_TOKEN'] = token_data["refresh_token"]
                
                display(HTML('<div style="padding: 20px; border: 2px solid #4CAF50; background-color: #d4edda;"><h3 style="color: #155724;">✓ Success!</h3></div>'))
                return token_data["access_token"]
            
            # Handle error response
            error_data = token_response.json()
            error = error_data.get("error", "")
            error_description = error_data.get("error_description", "")
            error_msg = error_description or error or token_response.text
            
            # Check if it's an "authorization_pending" or "slow_down" error
            # Check both the error code and the error message/description
            if (
                error == "authorization_pending" or
                error == "slow_down" or
                "authorization_pending" in error_msg.lower() or
                "slow_down" in error_msg.lower() or
                "authorization request is still pending" in error_msg.lower()
            ):
                # Still waiting for user authorization - keep polling
                if error == "slow_down":
                    interval += 5  # Increase polling interval
                time.sleep(interval)
                continue
            elif error in ["expired_token", "access_denied"]:
                raise Exception(f"Authentication failed: {error}")
            else:
                raise Exception(f"Unexpected error: {error_msg}")
        except requests.exceptions.RequestException as e:
            raise Exception(f"Network error: {e}")
    
    raise Exception("Timeout waiting for authorization")

# Usage
access_token = await get_access_token_device_flow()
print(f"Access token: {access_token[:50]}...")
```

### Method 1: Using requests library (Authorization Code Flow)

**Note:** This method works in JupyterLite. The browser will open in a new tab, and you'll need to copy the authorization code from the redirect URL.

```python
# In your Jupyter notebook (works in JupyterLite)
import requests
import urllib.parse
import secrets
from IPython.display import HTML, display

# Configuration
OIDC_BASE_URL = "http://localhost:3000/oidc"
CLIENT_ID = "default-client"
CLIENT_SECRET = "default-secret"
REDIRECT_URI = "http://localhost:8888/oidc/callback"  # Or use a custom callback handler
SCOPE = "openid profile email"

# Generate state for CSRF protection
state = secrets.token_urlsafe(32)

# Step 1: Build authorization URL
auth_params = {
    "client_id": CLIENT_ID,
    "response_type": "code",
    "redirect_uri": REDIRECT_URI,
    "scope": SCOPE,
    "state": state,
}

auth_url = f"{OIDC_BASE_URL}/auth?{urllib.parse.urlencode(auth_params)}"

# Step 2: Open browser for user to authenticate (JupyterLite compatible)
print("Please click the link below to authenticate:")
display(HTML(f'''
<div style="padding: 20px; border: 2px solid #4CAF50; border-radius: 5px; background-color: #f0f8f0;">
    <h3>🔐 Authorization Required</h3>
    <p><a href="{auth_url}" target="_blank" style="font-size: 18px; padding: 10px 20px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px;">Open Authorization Page</a></p>
    <p><small>After authorizing, copy the <code>code</code> parameter from the redirect URL</small></p>
</div>
'''))

# Alternative: Use JavaScript to open in new window (JupyterLite compatible)
try:
    from js import window
    window.open(auth_url, '_blank')
except ImportError:
    # Fallback if js module not available
    pass

# Step 3: User needs to paste the authorization code from the redirect URL
# The redirect URL will look like: http://localhost:8888/oidc/callback?code=...&state=...
print(f"\nAfter authorizing, the redirect URL will contain a 'code' parameter.")
print(f"Example: http://localhost:8888/oidc/callback?code=ABC123&state=...")
auth_code = input("Enter the authorization code from the redirect URL: ")

# Step 4: Exchange authorization code for tokens
token_response = requests.post(
    f"{OIDC_BASE_URL}/token",
    data={
        "grant_type": "authorization_code",
        "code": auth_code,
        "redirect_uri": REDIRECT_URI,
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
    },
    headers={"Content-Type": "application/x-www-form-urlencoded"},
)

if token_response.status_code == 200:
    token_data = token_response.json()
    access_token = token_data["access_token"]
    refresh_token = token_data.get("refresh_token")
    
    print(f"\n✓ Successfully authenticated!")
    print(f"Access Token: {access_token[:50]}...")
    print(f"Token expires in: {token_data.get('expires_in', 'N/A')} seconds")
    
    # Store token for later use
    import os
    os.environ['OIDC_ACCESS_TOKEN'] = access_token
    if refresh_token:
        os.environ['OIDC_REFRESH_TOKEN'] = refresh_token
else:
    print(f"Error getting token: {token_response.status_code}")
    print(token_response.text)
```

### Method 2: Using a local callback server (Better UX)

**Note:** This method does NOT work in JupyterLite (browser environment) because it requires starting a local HTTP server. Use Method 0 (Device Flow) or Method 1 instead for JupyterLite.

This method automatically captures the callback without manual code entry (works in regular Jupyter/notebooks):

```python
# In your Jupyter notebook
import requests
import urllib.parse
import secrets
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
from IPython.display import HTML, display

# Note: webbrowser.open() doesn't work in JupyterLite
# Use HTML display with clickable link instead

# Configuration
OIDC_BASE_URL = "http://localhost:3000/oidc"
CLIENT_ID = "default-client"
CLIENT_SECRET = "default-secret"
SCOPE = "openid profile email"

# Find an available port for callback
def find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('', 0))
        return s.getsockname()[1]

CALLBACK_PORT = find_free_port()
REDIRECT_URI = f"http://localhost:{CALLBACK_PORT}/callback"

# Store the authorization code
auth_code_container = {"code": None, "state": None, "error": None}

# Create a simple HTTP server to handle the callback
class CallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/callback'):
            # Parse query parameters
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            
            if 'code' in params:
                auth_code_container['code'] = params['code'][0]
                auth_code_container['state'] = params.get('state', [None])[0]
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b'<html><body><h1>Authentication successful!</h1><p>You can close this window.</p></body></html>')
            elif 'error' in params:
                auth_code_container['error'] = params['error'][0]
                self.send_response(400)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(f'<html><body><h1>Error: {params["error"][0]}</h1></body></html>'.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress server logs

# Start callback server
server = HTTPServer(('localhost', CALLBACK_PORT), CallbackHandler)
server_thread = threading.Thread(target=server.serve_forever)
server_thread.daemon = True
server_thread.start()

# Generate state
state = secrets.token_urlsafe(32)

# Build authorization URL
auth_params = {
    "client_id": CLIENT_ID,
    "response_type": "code",
    "redirect_uri": REDIRECT_URI,
    "scope": SCOPE,
    "state": state,
}

auth_url = f"{OIDC_BASE_URL}/auth?{urllib.parse.urlencode(auth_params)}"

# Open browser (JupyterLite compatible)
print(f"Opening browser for authentication...")
print(f"Callback will be received on: {REDIRECT_URI}")
display(HTML(f'''
<div style="padding: 20px; border: 2px solid #4CAF50; border-radius: 5px; background-color: #f0f8f0;">
    <h3>🔐 Authorization Required</h3>
    <p><a href="{auth_url}" target="_blank" style="font-size: 18px; padding: 10px 20px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px;">Open Authorization Page</a></p>
</div>
'''))

# Try to open with JavaScript (works in JupyterLite)
try:
    from js import window
    window.open(auth_url, '_blank')
except ImportError:
    pass

# Wait for callback (with timeout)
import time
timeout = 300  # 5 minutes
start_time = time.time()

while auth_code_container['code'] is None and auth_code_container['error'] is None:
    if time.time() - start_time > timeout:
        print("Timeout waiting for authorization code")
        break
    time.sleep(0.5)

# Stop the server
server.shutdown()

# Check for errors
if auth_code_container['error']:
    print(f"Authentication error: {auth_code_container['error']}")
elif auth_code_container['code']:
    # Exchange code for tokens
    token_response = requests.post(
        f"{OIDC_BASE_URL}/token",
        auth=(CLIENT_ID, CLIENT_SECRET),
        data={
            "grant_type": "authorization_code",
            "code": auth_code_container['code'],
            "redirect_uri": REDIRECT_URI,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    
    if token_response.status_code == 200:
        token_data = token_response.json()
        access_token = token_data["access_token"]
        refresh_token = token_data.get("refresh_token")
        
        print(f"✓ Successfully obtained access token!")
        print(f"Access Token: {access_token[:50]}...")
        print(f"Expires in: {token_data.get('expires_in', 'N/A')} seconds")
        
        # Store in environment
        import os
        os.environ['OIDC_ACCESS_TOKEN'] = access_token
        if refresh_token:
            os.environ['OIDC_REFRESH_TOKEN'] = refresh_token
        
        # You can now use the access_token
        # access_token is available in this variable
    else:
        print(f"Error getting token: {token_response.status_code}")
        print(token_response.text)
else:
    print("No authorization code received")
```

### Method 3: Using the access token to make API calls

Once you have the access token, you can use it to make authenticated requests:

```python
# Use the stored access token
import os
import requests

access_token = os.environ.get('OIDC_ACCESS_TOKEN')

if access_token:
    # Example: Get user info
    userinfo_response = requests.get(
        f"{OIDC_BASE_URL}/me",
        headers={"Authorization": f"Bearer {access_token}"}
    )
    
    if userinfo_response.status_code == 200:
        user_info = userinfo_response.json()
        print("User Info:", user_info)
    else:
        print(f"Error: {userinfo_response.status_code}")
        print(userinfo_response.text)
else:
    print("No access token found. Please authenticate first.")
```

### Method 4: Refresh token (if available)

```python
import requests
import os

refresh_token = os.environ.get('OIDC_REFRESH_TOKEN')
CLIENT_ID = "default-client"
CLIENT_SECRET = "default-secret"
OIDC_BASE_URL = "http://localhost:3000/oidc"

if refresh_token:
    # Refresh the access token
    refresh_response = requests.post(
        f"{OIDC_BASE_URL}/token",
        auth=(CLIENT_ID, CLIENT_SECRET),
        data={
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    
    if refresh_response.status_code == 200:
        token_data = refresh_response.json()
        new_access_token = token_data["access_token"]
        os.environ['OIDC_ACCESS_TOKEN'] = new_access_token
        print("Token refreshed successfully!")
    else:
        print(f"Error refreshing token: {refresh_response.status_code}")
        print(refresh_response.text)
```

### Note: Register client with notebook redirect URI

Make sure your oidc-provider client configuration includes the redirect URI you're using in the notebook (e.g., `http://localhost:8888/oidc/callback` for authorization code flow).

## Resources

- [JupyterHub OAuthenticator Documentation](https://oauthenticator.readthedocs.io/)
- [JupyterHub Authentication Guide](https://jupyterhub.readthedocs.io/en/stable/reference/authenticators.html)
- [oidc-provider Documentation](https://github.com/panva/node-oidc-provider)
- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
