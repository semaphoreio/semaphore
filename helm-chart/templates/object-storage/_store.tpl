{{- define "semaphore.objectStore.credentials" -}}
{{- $former := list "semaphore" (printf "semaphore-%s-access" .key) (printf "semaphore-%s-secret" .key) -}}
{{- if or (has .store.username $former) (has .store.password $former) -}}
{{- fail (printf "global.%s.username and global.%s.password are set to the chart's former default credentials; unset them to generate new ones, or set your own" .key .key) -}}
{{- end -}}
{{- $existing := lookup "v1" "Secret" .root.Release.Namespace .store.secretName -}}
{{- $data := dict -}}
{{- if $existing -}}
{{- $data = $existing.data | default dict -}}
{{- end -}}
{{- $accessKey := .store.username | default (get $data "AWS_ACCESS_KEY_ID" | default "" | b64dec) -}}
{{- $secretKey := .store.password | default (get $data "AWS_SECRET_ACCESS_KEY" | default "" | b64dec) -}}
{{- if not .store.local.enabled -}}
{{- $accessKey = required (printf "global.%s.username is required when global.%s.local.enabled is false" .key .key) $accessKey -}}
{{- $secretKey = required (printf "global.%s.password is required when global.%s.local.enabled is false" .key .key) $secretKey -}}
{{- end -}}
{{- $accessKey = $accessKey | default (randAlphaNum 20) -}}
{{- $secretKey = $secretKey | default (randAlphaNum 40) -}}
{{- dict "accessKey" $accessKey "secretKey" $secretKey | toJson -}}
{{- end -}}
{{- define "semaphore.objectStore" -}}
{{- $image := required (printf "global.%s.local.image.repository and global.%s.local.image.tag are required" .key .key) .store.local.image -}}
{{- $repository := required (printf "global.%s.local.image.repository is required" .key) $image.repository -}}
{{- $tag := required (printf "global.%s.local.image.tag is required" .key) $image.tag -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    app: {{ .name }}
    product: semaphoreci
spec:
  type: ClusterIP
  ports:
  - port: 9000
    targetPort: 9000
  selector:
    app: {{ .name }}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .name }}
  labels:
    app: {{ .name }}
    product: semaphoreci
spec:
  serviceName: {{ .name }}
  replicas: 1
  selector:
    matchLabels:
      app: {{ .name }}
  template:
    metadata:
      annotations:
        checksum/credentials: {{ printf "%s\n%s" .store.username .store.password | sha256sum }}
      labels:
        app: {{ .name }}
        product: semaphoreci
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        fsGroupChangePolicy: OnRootMismatch
      initContainers:
      - name: prepare-data
        image: "{{ $repository }}:{{ $tag }}"
        securityContext:
          runAsUser: 0
          runAsGroup: 0
          runAsNonRoot: false
        command: ["sh", "-c", "mkdir -p /data/{{ .bucket }} && chown 10001:10001 /data /data/{{ .bucket }}"]
        volumeMounts:
        - name: data
          mountPath: "/data"
      containers:
      - name: {{ .name }}
        image: "{{ $repository }}:{{ $tag }}"
        env:
          - name: RUSTFS_ACCESS_KEY
            valueFrom:
              secretKeyRef:
                name: {{ .store.secretName }}
                key: AWS_ACCESS_KEY_ID
          - name: RUSTFS_SECRET_KEY
            valueFrom:
              secretKeyRef:
                name: {{ .store.secretName }}
                key: AWS_SECRET_ACCESS_KEY
          - name: RUSTFS_REGION
            value: {{ .store.region | quote }}
          - name: RUSTFS_CHECK_UPDATE
            value: "false"
          - name: RUSTFS_OBS_LOG_DIRECTORY
            value: ""
          - name: RUSTFS_CONSOLE_ENABLE
            value: "false"
          {{- range .extraEnv }}
          - name: {{ .name }}
            value: {{ .value | quote }}
          {{- end }}
        ports:
        - containerPort: 9000
        resources:
          {{- toYaml .store.local.resources | nindent 10 }}
        volumeMounts:
        - name: data
          mountPath: "/data"
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 15
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: {{ .store.local.size }}
{{- end }}
