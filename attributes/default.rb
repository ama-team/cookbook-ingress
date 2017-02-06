default['ama-ingress']['nginx']['image'] = 'nginx:1.11-alpine'
default['ama-ingress']['haproxy']['image'] = 'haproxy:1.7-alpine'
default['ama-ingress']['root'] = '/srv/ingress'
default['ama-ingress']['resolver'] = nil
default['ama-ingress']['networks'] = []