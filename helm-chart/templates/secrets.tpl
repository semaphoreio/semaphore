{{- define "secrets.jwt.name" }}
{{- if eq .Values.global.jwt.secretName "" }}
{{- printf "%s-jwt" .Release.Name }}
{{- else }}
{{- .Values.global.jwt.secretName }}
{{- end }}
{{- end }}

{{- define "secrets.authentication.name" }}
{{- if eq .Values.global.authentication.secretName "" }}
{{- printf "%s-authentication" .Release.Name }}
{{- else }}
{{- .Values.global.authentication.secretName }}
{{- end }}
{{- end }}

{{- define "secrets.encryption.name" }}
{{- if eq .Values.global.encryption.secretName "" }}
{{- printf "%s-encryption" .Release.Name }}
{{- else }}
{{- .Values.global.encryption.secretName }}
{{- end }}
{{- end }}

{{- define "secrets.openid.name" }}
{{- if eq .Values.global.openid.secretName "" }}
{{- printf "%s-openid" .Release.Name }}
{{- else }}
{{- .Values.global.openid.secretName }}
{{- end }}
{{- end }}

{{- define "secrets.vault.name" }}
{{- if eq .Values.global.vault.secretName "" }}
{{- printf "%s-vault" .Release.Name }}
{{- else }}
{{- .Values.global.vault.secretName }}
{{- end }}
{{- end }}
