{{/*
_helpers.tpl — reusable snippets. Files starting with "_" are NOT rendered as
Kubernetes objects; they only define named templates other files can call.

Why bother: without this, the string "uptime-kuma" and its label set would be
repeated in the Deployment, Service, PVC and Namespace. Change it in three
places and forget the fourth, and the Service silently selects nothing — a
classic outage with no error message anywhere.

Defining it once means the selector and the pod labels CANNOT drift apart.
*/}}

{{/* Base name. Overridable via nameOverride. */}}
{{- define "uptime-kuma.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified name used for actual object names.
Truncated to 63 chars because that is the Kubernetes limit for a label value.
*/}}
{{- define "uptime-kuma.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Full label set, following the Kubernetes recommended labels spec.
Applied to every object so `kubectl get all -l app.kubernetes.io/name=uptime-kuma`
returns the whole application. The raw manifests only had `app: uptime-kuma`.
*/}}
{{- define "uptime-kuma.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "uptime-kuma.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: infra
{{- end -}}

{{/*
Selector labels ONLY.

Two separate reasons this is a smaller, stable subset:

1. A Deployment's spec.selector.matchLabels is IMMUTABLE after creation. If the
   chart version or app version were included here, bumping the chart would
   change the selector and the API server would reject the update outright
   ("field is immutable"). Selectors must be boring and permanent.

2. MIGRATION CONSTRAINT — this is why it is `app:` and not the more idiomatic
   `app.kubernetes.io/name:`. The Deployment and Service already running in the
   cluster were created from raw manifests using `app: uptime-kuma`. Emitting a
   different selector here would mean ArgoCD tries to patch an immutable field,
   the sync fails, and the status page stays broken.

   Adopting a live workload means matching what is already there. The richer
   app.kubernetes.io/* labels are still applied via "uptime-kuma.labels" — they
   are just not part of the selector.
*/}}
{{- define "uptime-kuma.selectorLabels" -}}
app: {{ include "uptime-kuma.name" . }}
{{- end -}}
