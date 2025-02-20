{{- define "env.db.go" }}
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.database.secretName }}
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.database.secretName }}
      key: password
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.database.secretName }}
      key: host
- name: DB_PORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.database.secretName }}
      key: port
{{- end }}

{{- define "env.db.elixir" }}
- name: POSTGRES_DB_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.database.secretName }}
      key: host
- name: POSTGRES_DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.database.secretName }}
      key: username
- name: POSTGRES_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.database.secretName }}
      key: password
{{- end }}
