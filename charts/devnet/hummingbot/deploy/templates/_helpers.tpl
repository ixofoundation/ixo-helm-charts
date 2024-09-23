{{/*
Common helper templates for the Helm chart.
*/}}

{{- define "hummingbot-chart.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "hummingbot-chart.fullname" -}}
{{- $name := include "hummingbot-chart.name" . -}}
{{- if .Values.global.nameOverride }}{{ .Values.global.nameOverride }}-{{ $name }}{{ else }}{{ $name }}{{ end -}}
{{- end -}}

{{- define "hummingbot-chart.serviceName" -}}
{{- $name := include "hummingbot-chart.fullname" . -}}
{{- if .Values.dashboard.service.name }}{{ .Values.dashboard.service.name }}{{ else }}{{ $name }}-service{{ end -}}
{{- end -}}

{{- define "hummingbot-chart.selectorLabels" -}}
app: {{ include "hummingbot-chart.name" . }}
{{- if .Values.global.labels }}{{ .Values.global.labels | toYaml | nindent 2 }}{{ end -}}
{{- end -}}

{{- define "hummingbot-chart.namespace" -}}
{{ .Release.Namespace }}
{{- end -}}

{{- define "hummingbot-chart.annotations" -}}
{{- if .Values.global.annotations }}{{ .Values.global.annotations | toYaml | nindent 2 }}{{ end -}}
{{- end -}}