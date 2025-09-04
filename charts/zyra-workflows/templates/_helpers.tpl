{{- define "zyra.fullname" -}}
{{- printf "%s" .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zyra.datasetName" -}}
{{- $root := index . 0 -}}
{{- $ds := index . 1 -}}
{{- printf "%s-%s" (include "zyra.fullname" $root) $ds.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zyra.labels" -}}
app.kubernetes.io/name: {{ include "zyra.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "zyra.configmapName" -}}
{{- $root := index . 0 -}}
{{- $ds := index . 1 -}}
{{- printf "%s-%s-env" (include "zyra.fullname" $root) $ds.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

