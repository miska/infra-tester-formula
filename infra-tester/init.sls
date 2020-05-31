{%- set def_root = '/srv/tester' %}
{%- set data = pillar.get('tester', None) %}

tester_root:
  file.directory:
    - name: {{ data.get('root', def_root) }}
    - user: tester
    - dir_mode: 0755
    - makedirs: True

tester_user:
  user.present:
    - name: tester
    - home: {{ data.get('root', def_root) }}
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
{% endif %}
