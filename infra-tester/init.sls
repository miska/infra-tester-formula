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

{% for name, cfg in data['mail'].items() %}
{{ name }}_mail_script:
  file.managed:
    - name: {{ root }}/mail_{{ name }}/mail_check
    - context:
        middleman: {{ cfg['middleman'] }}
        last_mail_hours: {{ cfg.get('last_mail_hours', 1) }}
        mails_waiting_num: {{ cfg.get('mails_waiting_num', 5) }}
        subject: {{ cfg.get('subject', 'Testing e-mail') }}
    - template: jinja
    - makedirs: True
    - user: {{ user }}
    - mode: 755
    - source:
      - salt://infra-tester/templates/mail_check
    - require:
      - tester_user
      - tester_mail_packages

{{ name }}_msmtprc:
  file.managed:
    - name: {{ root }}/mail_{{ name }}/msmtprc
    - makedirs: True
    - user: {{ user }}
    - mode: 600
    - contents: |
       account test
       tls on
       port {{ cfg.get('smtp_port', 587) }}
       host {{ cfg.get('smtp', 'smtp.' + name) }}
       auth on
       from {{ cfg.get('from', cfg['login']) }}
       user {{ cfg['login'] }}
       password {{ cfg['password'] }}
       account default : test
    - require:
      - tester_user
      - tester_mail_packages

{{ name }}_mailstore:
  file.directory:
    - name: {{ root }}/mail_{{ name }}/Mails
    - user: {{ user }}
    - dir_mode: 0755
    - makedirs: True
    - require:
      - tester_user


{{ name }}_mbsyncrc:
  file.managed:
    - name: {{ root }}/mail_{{ name }}/mbsyncrc
    - makedirs: True
    - user: {{ user }}
    - mode: 600
    - contents: |
        # Imap account
        IMAPStore testimap
        SSLType STARTTLS
        SystemCertificates yes
        Host {{ cfg.get('imap', 'imap.' + name) }}
        User {{ cfg['login'] }}
        Pass {{ cfg['password'] }}

        # Local account
        MaildirStore testmaildir
        Flatten .
        Path {{ root }}/mail_{{ name }}/Mails
        Inbox {{ root }}/mail_{{ name }}/Mails/INBOX

        # Mapping
        Channel default
        Master :testimap:
        Slave  :testmaildir:
        Create Slave
        SyncState *
        Expunge Both
        Pattern *
    - require:
      - tester_user
      - tester_mail_packages

{{ name }}_mail_cron:
  cron.present:
    - user: {{ user }}
    - name: '{{ root }}/mail_{{ name }}/mail_check > {{ cfg.get('report', root + '/mail_' + name + '/report.txt') }}'
    - minute: '*/{{ cfg.get('minutes', 10) }}'
    - identifier: {{ name }}_mail
    - require:
      - {{ name }}_mail_script
      - {{ name }}_msmtprc
      - {{ name }}_mailstore
      - {{ name }}_mbsyncrc
{% endfor %}
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
        timeout: {{ cfg.get('timeout', 300) }}
        mode: {{ cfg.get('report_mode', '0644') }}
    - template: jinja
    - makedirs: True
    - user: {{ user }}
    - mode: 755
    - source:
      - salt://infra-tester/templates/dns_check
    - require:
      - tester_user
      - tester_dns_packages

{{ name }}_dns_cron:
  cron.present:
    - user: {{ user }}
    - name: '{{ root }}/dns_{{ name }}/dns_check {{ cfg.get('report', root + '/dns_' + name + '/report.txt') }}'
    - minute: '*/{{ cfg.get('minutes', 10) }}'
    - identifier: {{ name }}_dns
    - require:
      - {{ name }}_dns_script

{% endfor %}
{% endif %}
