{{/*
Expand the name of the chart.
*/}}
{{- define "ixo-matrix-claims-bot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ixo-matrix-claims-bot.fullname" -}}
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
{{- define "ixo-matrix-claims-bot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ixo-matrix-claims-bot.labels" -}}
helm.sh/chart: {{ include "ixo-matrix-claims-bot.chart" . }}
{{ include "ixo-matrix-claims-bot.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ixo
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ixo-matrix-claims-bot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ixo-matrix-claims-bot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: ixo
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ixo-matrix-claims-bot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ixo-matrix-claims-bot.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
