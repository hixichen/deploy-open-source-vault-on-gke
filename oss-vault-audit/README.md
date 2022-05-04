# usage exmple:

reference: https://github.com/inter169/systs/blob/master/alpine/crond/README.md

## env:

```
          env:
            - name: LOGROTATE_FILE_PATH
              value: "/vault/audit/vault-audit.log"
            - name: CRON_SCHEDULE
              value: "*/5 *  * * *"
          volumeMounts:
            - name: audit-config
              mountPath: /etc/logrotate.d
      volumes:
        - name: audit-config
          configMap:
            name: oss-vault-audit-config
```

## config:

```
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: oss-vault-audit-config
data:
  audit-log.conf: |
    /vault/audit/*.log {
        su
        missingok
        rotate 5
        size 1M
        compress
        delaycompress
        dateformat -%Y%m%d_%H%M%S
        notifempty
        copytruncate
        postrotate
          set -ue
          # send SIGHUP to Vault container.
          kill -1 $(cat /vault/audit/pidfile.pid)
        endscript
    }
```
