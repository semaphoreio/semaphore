{{- define "initContainers.all" -}}
{{- if not (or .Values.global.database.local.enabled .Values.global.rabbitmq.local.enabled) }}
{{- list }}
{{- else }}
{{ $containers := list }}
{{- if .Values.global.database.local.enabled }}
{{- range $container := (include "initContainers.waitForPostgres" . | fromYamlArray) }}
{{- $containers = append $containers $container }}
{{- end }}
{{- end }}
{{- if .Values.global.rabbitmq.local.enabled }}
{{- range $container := (include "initContainers.waitForRabbitMQ" . | fromYamlArray) }}
{{- $containers = append $containers $container }}
{{- end }}
{{- end }}
{{- $containers | toYaml }}
{{- end }}
{{- end }}

{{- define "initContainers.waitForPostgres" -}}
{{- if .Values.global.database.local.enabled }}
- name: wait-for-postgres
  image: postgres:13
  command:
    - /bin/sh
    - -c
    - |
      until pg_isready -h $POSTGRES_DB_HOST -p $POSTGRES_DB_PORT -U $POSTGRES_DB_USER
      do
        echo "Waiting for postgres at: $POSTGRES_DB_HOST:$POSTGRES_DB_PORT"
        sleep 2;
      done
  env:
    - name: POSTGRES_DB_PORT
      valueFrom:
        secretKeyRef:
          name: {{ .Values.global.database.secretName }}
          key: port
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
{{- else }}
{{- list }}
{{- end }}
{{- end }}

{{- define "initContainers.waitForRabbitMQ" -}}
{{- if .Values.global.rabbitmq.local.enabled }}
- name: wait-for-rabbitmq
  image: curlimages/curl:latest
  command:
    - /bin/sh
    - -ec
    - |
      RABBITMQ_USER=$(echo $AMQP_URL | sed -E 's/^amqp:\/\/([^:]+):.*$/\1/')
      RABBITMQ_PASSWORD=$(echo $AMQP_URL | sed -E 's/^amqp:\/\/[^:]+:([^@]+)@.*$/\1/')
      RABBITMQ_HOST=$(echo $AMQP_URL | sed -E 's/^amqp:\/\/[^@]+@([^:\/]+).*$/\1/')
      
      until curl -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" -s "http://$RABBITMQ_HOST:15672/api/healthchecks/node" | grep '"status":"ok"'
      do
        echo "Waiting for RabbitMQ at: http://${RABBITMQ_HOST}:15672"
        sleep 2;
      done
  env:
    - name: AMQP_URL
      valueFrom:
        secretKeyRef:
          name: {{ .Values.global.rabbitmq.secretName }}
          key: amqp-url
{{- else }}
{{- list }}
{{- end }}
{{- end }}