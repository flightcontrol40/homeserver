{{/*
Generic deployment template for media services
Usage: include "mediastack.deployment" (dict "service" "radarr" "context" $)
*/}}
{{- define "mediastack.deployment" -}}
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $serviceName }}
  namespace: {{ $.Values.global.namespace }}
  labels:
    {{- include "mediastack.labels" $ | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ $serviceName }}
      app.kubernetes.io/instance: {{ $.Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ $serviceName }}
        app.kubernetes.io/instance: {{ $.Release.Name }}
        app.kubernetes.io/component: {{ $serviceName }}
    spec:
      {{- if $.Values.nodeAffinity }}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - {{ $.Values.nodeAffinity.hostname }}
      {{- end }}
      containers:
        - name: {{ $serviceName }}
          image: "{{ $values.image.repository }}:{{ $values.image.tag }}"
          imagePullPolicy: {{ $.Values.global.imagePullPolicy }}
          ports:
            - name: http
              containerPort: {{ $values.service.port }}
              protocol: TCP
          env:
            {{- include "mediastack.commonEnv" $ | nindent 12 }}
            {{- with $values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          volumeMounts:
            - name: config
              mountPath: /config
            {{- if $.Values.storage.media.enabled }}
            - name: media
              mountPath: /data/media
            {{- end }}
            {{- if $.Values.storage.downloads.enabled }}
            - name: downloads
              mountPath: /data/downloads
            {{- end }}
          {{- with $values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      volumes:
        - name: config
          persistentVolumeClaim:
            claimName: {{ $serviceName }}-config-pvc
        {{- if $.Values.storage.media.enabled }}
        - name: media
          persistentVolumeClaim:
            claimName: media-pvc
        {{- end }}
        {{- if $.Values.storage.downloads.enabled }}
        - name: downloads
          persistentVolumeClaim:
            claimName: downloads-pvc
        {{- end }}
{{- end }}
{{- end }}

{{/*
Generic service template
*/}}
{{- define "mediastack.service" -}}
{{- $serviceName := .service -}}
{{- $ := .context -}}
{{- $values := index $.Values $serviceName -}}
{{- if $values.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $serviceName }}
  namespace: {{ $.Values.global.namespace }}
  labels:
    {{- include "mediastack.labels" $ | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
spec:
  type: ClusterIP
  ports:
    - port: {{ $values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: {{ $serviceName }}
    app.kubernetes.io/instance: {{ $.Release.Name }}
{{- end }}
{{- end }}

{{/*
Generic ingress template
*/}}
{{- define "mediastack.ingress" -}}
{{- $serviceName := .service -}}
{{- $ := .context -}}
{{- $values := index $.Values $serviceName -}}
{{- if and $values.enabled $values.ingress.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $serviceName }}
  namespace: {{ $.Values.global.namespace }}
  labels:
    {{- include "mediastack.labels" $ | nindent 4 }}
    app.kubernetes.io/component: {{ $serviceName }}
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: {{ $.Values.global.traefik.entrypoint }}
    {{- if $.Values.global.traefik.tls.enabled }}
    traefik.ingress.kubernetes.io/router.tls: "true"
    {{- end }}
    {{- $middlewares := include "mediastack.traefikMiddlewares" (dict "global" $.Values.global "service" $values) }}
    {{- if $middlewares }}
    traefik.ingress.kubernetes.io/router.middlewares: {{ $middlewares }}
    {{- end }}
spec:
  ingressClassName: traefik
  {{- if $.Values.global.traefik.tls.enabled }}
  tls:
    - hosts:
        - {{ $values.ingress.host }}.{{ $.Values.global.domain }}
      secretName: {{ $serviceName }}-tls
  {{- end }}
  rules:
    - host: {{ $values.ingress.host }}.{{ $.Values.global.domain }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ $serviceName }}
                port:
                  number: {{ $values.service.port }}
{{- end }}
{{- end }}
