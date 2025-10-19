{{/*
Expand the name of the chart.
*/}}
{{- define "mediastack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mediastack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mediastack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mediastack.labels" -}}
helm.sh/chart: {{ include "mediastack.chart" . }}
{{ include "mediastack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mediastack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mediastack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common environment variables for all containers
*/}}
{{- define "mediastack.commonEnv" -}}
- name: PUID
  value: {{ .Values.global.puid | quote }}
- name: PGID
  value: {{ .Values.global.pgid | quote }}
- name: TZ
  value: {{ .Values.global.timezone | quote }}
- name: UMASK
  value: {{ .Values.global.umask | quote }}
{{- end }}

{{/*
Common volume mounts for media storage
*/}}
{{- define "mediastack.mediaVolumeMounts" -}}
- name: media
  mountPath: /data/media
  subPath: media
- name: media
  mountPath: /data/downloads
  subPath: downloads
{{- end }}

{{/*
Common volumes for media storage
*/}}
{{- define "mediastack.mediaVolumes" -}}
- name: media
  persistentVolumeClaim:
    claimName: media-pvc
{{- end }}

{{/*
Create a service name for a component
*/}}
{{- define "mediastack.serviceName" -}}
{{- $name := index . 0 -}}
{{- $context := index . 1 -}}
{{- printf "%s-%s" (include "mediastack.fullname" $context) $name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create ingress hostname
*/}}
{{- define "mediastack.ingressHost" -}}
{{- $service := index . 0 -}}
{{- $values := index . 1 -}}
{{- $global := index . 2 -}}
{{- if $values.ingress.host -}}
{{- printf "%s.%s" $values.ingress.host $global.domain }}
{{- else -}}
{{- printf "%s.%s" $service $global.domain }}
{{- end }}
{{- end }}

{{/*
Generate Traefik middleware annotation
*/}}
{{- define "mediastack.traefikMiddlewares" -}}
{{- $global := .global -}}
{{- $service := .service -}}
{{- $middlewares := list -}}
{{- range $global.traefik.middlewares -}}
{{- $middlewares = append $middlewares . -}}
{{- end -}}
{{- if $service.ingress.middlewares -}}
{{- range $service.ingress.middlewares -}}
{{- $middlewares = append $middlewares . -}}
{{- end -}}
{{- end -}}
{{- if $middlewares -}}
{{- join "," $middlewares }}
{{- end -}}
{{- end }}

{{/*
Generate a PVC for service config storage
Usage: include "mediastack.configPVC" (dict "service" "radarr" "context" $)
*/}}
{{- define "mediastack.configPVC" -}}
{{- $serviceName := .service -}}
{{- $ := .context -}}
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
