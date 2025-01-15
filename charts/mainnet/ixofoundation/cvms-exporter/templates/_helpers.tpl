{{- define "cvms.labels" -}}
app: {{ .Chart.Name }}
release: {{ .Release.Name }}
{{- end -}}