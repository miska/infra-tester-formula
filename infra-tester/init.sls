{%- set data = pillar.get('infra-tester', None) %}
{%- set root = data.get('root', '/srv/tester') %}
{%- set user = data.get('user', 'tester') %}

tester_root:
  file.directory:
    - name: {{ root }}
    - user: {{ user }}
    - dir_mode: 0755
    - makedirs: True
    - require:
      - tester_user

tester_user:
  user.present:
    - name: {{ user }}
    - home: {{ root }}
    - shell: /sbin/nologin

{% if data.get('mail', False) %}
tester_mail_packages:
  pkg.latest:
    - refresh: True
    - pkgs:
      - isync
      - msmtp

{% endif %}

{% if data.get('dns', False) %}
tester_dns_packages:
  pkg.latest:
    - refresh: True
    - pkgs:
      - bind-utils

{% for name, cfg in data['dns'].items() %}
{{ name }}_dns_script:
  file.managed:
    - name: {{ root }}/dns_{{ name }}/dns_check
    - context: 
        domains: {{ cfg['domains'] }}
    - template: jinja
    - makedirs: True
    - user: {{ user }}
    - mode: 755
    - source:
      - salt://infra-tester/templates/dns_check
    - require:
      - tester_user

{{ name }}_dns_cron:
  cron.present:
    - user: {{ user }}
    - name: '{{ root }}/dns_{{ name }}/dns_check > {{ cfg.get('report', root + '/dns_' + name + '/report.txt') }}'
    - minute: '*/{{ cfg.get('minutes', 10) }}'
    - identifier: {{ name }}_dns
    - require:
      - {{ name }}_dns_script

{% endfor %}
{% endif %}
