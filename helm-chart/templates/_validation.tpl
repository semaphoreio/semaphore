{{/*
Validate global.edition value
*/}}
{{- define "semaphore.validateEdition" -}}
{{- $validEditions := list "ce" "ee" -}}
{{- if not (has .Values.global.edition $validEditions) -}}
{{- fail (printf "Invalid edition value: %s. Must be one of: %s" .Values.global.edition (join ", " $validEditions)) -}}
{{- end -}}
{{- end -}}
