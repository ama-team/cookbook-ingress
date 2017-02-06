# Draft warning

This cookbook is in active development. I hope we will hit stable release soon!

# ama-ingress Cookbook

This cookbook is a heavily opinionated way to configure Nginx with 
HAProxy as ingress router for http/https requests and tcp/udp/tls 
streams. This cookbook is developed as a solution to provide partial 
access into private local docker network, and because of that whole 
setup is managed inside docker-compose. Container are also using
host network, so 127.0.0.1 may be used to access current host.

## Requirements

### Platforms

- Ubuntu

Should work on other platforms as well, but not tested at all.

### Chef

- Chef 12.0 or later

### Cookbooks

- `ama-docker-compose` - the internal configuration is done via docker-compose.

## Attributes

| Key                                   | Default              | Description               |
|:--------------------------------------|:---------------------|:--------------------------|
| `['ama-ingress']['nginx']['image']`   | `nginx:1.11-alpine`  | Nginx docker image name   |
| `['ama-ingress']['haproxy']['image']` | `haproxy:1.7-alpine` | HAProxy docker image name |
| `['ama-ingress']['root']`             | `/srv/ingress`       | Location where all configuration files will be stored |
| `['ama-ingress']['resolver']`         | no value set         | DNS resolver to use throughout configuration |
| `['ama-ingress']['networks']`         | `[]`                 | List of internal Docker networks containers have to be attached to |


## Resources

### http_ingress / https_ingress

`http_ingress` and `https_ingress` resources simply catch corresponding
HTTP traffic and reroute it according to provided rules

```ruby
http_ingress 'api.example.com' do
  # name property; port 80 is implied
  source 'api.example.com'
  target 'http://api.srv.example.com'
  rules({
    '/' => :cloak,
    '/raw' => :pass,
    '/docs?' => {
      type: :filesystem,
      target: '/var/www/docs',
      match_type: :regexp,
      extra_directives: [
        ['proxy_set_header', 'Access-Control-Allow-Origin', '*']
      ]
    },
    '/secure' => {
      type: :redirect,
      target: 'https://api.example.com',
      match_type: :exact,
      persistent: true
    }
  })
  extra_directives [
    ['client_max_body_size', '128MB']
  ]
  resolver '127.0.0.1:53'
end
```

```ruby
https_ingress 'api.example.com' do
  source 'api.example.com'
  target 'https://api.srv.example.com'
  certificate '/etc/certs/example.com.pem'
  key '/etc/certs/example.com.pem'
  # ...
end
```

Besides standard configuration, HTTP(S) ingress provide path-based
routing. There are several types of routing rules:

| Type          | Description |
|:--------------|:------------|
| `:pass`       | Pass request further via `proxy_pass` using source as `Host` header |
| `:cloak`      | Same as pass, but keep original `Host` header value |
| `:filesystem` | Maps request to local filesystem |
| `:fcgi`       | Transform request into FCGI request |
| `:redirect`   | Return redirect response |

Please note that filesystem and fcgi types should not be considered 
stable, because most of setups combine them and it is not clear how to 
do it yet. Ingress was intended to be just a proxy at first.

Every rule may be represented as type or hash with additional options:

```ruby
rules({'/' => :pass})
# the same as
rules({
  '/' => {
    type: :pass
  }
})
```

additional options are:

| Option | Description |
|:-------|:------------|
| `target` |
| `match_type` |
| `extra_directives` |
| `persistent`         | Used for `:redirect` only, distinguishes 301/302 response |

### tls_ingress

This resource a way to configure SNI proxy to allow TLS stream 
redirection without actually termination TLS connection.

```ruby
tls_ingress 'amqp.infra.example.com' do
  # name property
  source 'amqp.infra.example.com:5672'
  # may be also specified as array of targets
  # if any target misses port part, source port will be used
  target 'amqp-01.srv.example.com'
  # would override node['ama-ingress']['resolver']
  resolver '127.0.0.1:53'
  extra_directives []
end
```

TLS ingress is implemented using Nginx and HAProxy, because Nginx 
doesn't support SNI proxying. SNIProxy, as i've understood, doesn't
support multiple backends.
`extra_directives` currently refer to nginx only.

### tcp_ingress

```ruby
tcp_ingress 'amqp.srv.example.com:5672' do
  source_port 5672
  # may be also specified as array of targets
  # if any target misses port part, source_port will be used
  target 'amqp.srv.example.com:5672'
  resolver '127.0.0.1:53'
end
```

It is usually sufficient to specify it as one-liner:

```ruby
# source_port and target would be computed automatically
tcp_ingress 'amqp.srv.example.com:5672'
```

### udp_ingress

```ruby
udp_ingress '10.0.0.10:53' do
  source_port 53
  # may be also specified as array of targets
  # if any target misses port part, source_port will be used
  target '10.0.0.10:53'
  # You won't need resolver in this case, of course, but may need in others
  resolver '127.0.0.1:53'
end
```

As with tcp_ingress, one-liner may be used:

```ruby
udp_ingress '10.0.0.10:53'
```

### Internals

Traffic flows in following way:

- All TCP, UDP and HTTP ingress end up directly on Nginx
- TLS and HTTPS ingress hit HAProxy. Internally if none of SNI routing
rules match, TCP stream considered to be HTTPS and offloaded to Nginx, 
which is listening on specific UNIX socket.
 
Basically that means that only TLS and HTTPS ports may intersect.

## Contributing

1. Fork the repository on GitHub
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

## License and Authors

Authors: AMA Team  
License: MIT

