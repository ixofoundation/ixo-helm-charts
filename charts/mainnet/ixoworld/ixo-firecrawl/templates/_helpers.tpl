{{/*
Expand the name of the chart.
*/}}
{{- define "ixo-firecrawler.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ixo-firecrawler.fullname" -}}
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
{{- define "ixo-firecrawler.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ixo-firecrawler.labels" -}}
helm.sh/chart: {{ include "ixo-firecrawler.chart" . }}
{{ include "ixo-firecrawler.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ixo
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ixo-firecrawler.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ixo-firecrawler.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: ixo
{{- end }}

{{/*
Selector labels for API deployment (used by API Service)
*/}}
{{- define "ixo-firecrawler.apiSelectorLabels" -}}
{{ include "ixo-firecrawler.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
Selector labels for MCP deployment (used by MCP Service)
*/}}
{{- define "ixo-firecrawler.mcpSelectorLabels" -}}
{{ include "ixo-firecrawler.selectorLabels" . }}
app.kubernetes.io/component: mcp-server
{{- end }}

{{/*
Selector labels for Playwright deployment (used by Playwright Service)
*/}}
{{- define "ixo-firecrawler.playwrightSelectorLabels" -}}
{{ include "ixo-firecrawler.selectorLabels" . }}
app.kubernetes.io/component: playwright-service
{{- end }}

{{/*
Playwright Service URL for in-cluster API → Playwright.
Uses K8s FQDN: <service>.<namespace>.svc.cluster.local so it works in any namespace.
*/}}
{{- define "ixo-firecrawler.playwrightServiceURL" -}}
http://{{ include "ixo-firecrawler.fullname" . }}-playwright.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.playwrightPort }}/scrape
{{- end }}

{{/*
API Service URL for in-cluster MCP → API.
Uses K8s FQDN: <service>.<namespace>.svc.cluster.local so it works in any namespace.
*/}}
{{- define "ixo-firecrawler.apiServiceURL" -}}
http://{{ include "ixo-firecrawler.fullname" . }}-api.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.apiPort }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ixo-firecrawler.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ixo-firecrawler.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

