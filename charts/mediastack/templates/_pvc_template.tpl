
{{- define "mediastack.pvc" -}}
{{- $serviceName := .service -}}
{{- $ := .context -}}
{{- $values := index $.Values $serviceName -}}
{{- if $values.enabled }}
{{- if $.Values.storage.config.enabled }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ $serviceName }}-config-pvc
  namespace: {{ $.Values.global.namespace }}
  labels:
    {{- include "mediastack.labels" $ | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
    storage-type: config
spec:
  accessModes:
    - {{ $.Values.storage.config.accessMode }}
  storageClassName: {{ $.Values.storage.config.storageClass }}
  resources:
    requests:
      storage: {{ $.Values.storage.config.size }}
{{- end }}
{{- end }}
{{- end }}
