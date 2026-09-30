{{- define "semaphore.objectStore" -}}
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
        image: "{{ .store.local.image.repository }}:{{ .store.local.image.tag }}"
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
        image: "{{ .store.local.image.repository }}:{{ .store.local.image.tag }}"
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
