---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: ${namespace_name}
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
  annotations:
    cert-manager.io/issuer: ${issuer_name}
    cert-manager.io/issuer-kind: ${issuer_kind}
    cert-manager.io/issuer-group: cert-manager.k8s.cloudflare.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: 'true'
    external-dns.alpha.kubernetes.io/hostname: walrus.${domain_name}
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - walrus.${domain_name}
      secretName: walrus-${dash_domain_name}
  rules:
  - host: walrus.${domain_name}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: walrus
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: ${namespace_name}
  name: walrus-minio-ingress
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "minio"
  annotations:
    cert-manager.io/issuer: ${issuer_name}
    cert-manager.io/issuer-kind: ${issuer_kind}
    cert-manager.io/issuer-group: cert-manager.k8s.cloudflare.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: 'true'
    external-dns.alpha.kubernetes.io/hostname: minio.${domain_name}
    
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - minio.${domain_name}
      secretName: minio-${dash_domain_name}
  rules:
  - host: minio.${domain_name}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio
            port:
              number: 9001
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: ${namespace_name}
  name: walrus-apiminio-ingress
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "minio"
  annotations:
    cert-manager.io/issuer: ${issuer_name}
    cert-manager.io/issuer-kind: ${issuer_kind}
    cert-manager.io/issuer-group: cert-manager.k8s.cloudflare.com
    external-dns.alpha.kubernetes.io/cloudflare-proxied: 'true'
    external-dns.alpha.kubernetes.io/hostname: apiminio.${domain_name}
    
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - apiminio.${domain_name}
      secretName: apiminio-${dash_domain_name}
  rules:
  - host: apiminio.${domain_name}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio
            port:
              number: 9000
---
apiVersion: v1
kind: Secret
metadata:
  namespace: ${namespace_name}
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "configuration"
stringData:
  local_environment_mode: "disabled"
  enable_tls: "false"
  db_driver: "postgres"
  db_user: "root"
  db_password: "Root123"
  db_name: "walrus"
  minio_root_user: "minio"
  minio_root_password: "Minio123"
  minio_bucket: "walrus"
---
# Database
#
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: ${namespace_name}
  name: database-script
data:
  "init.sh": |
    #!/usr/bin/env bash

    set -o errexit
    set -o nounset
    set -o pipefail

    if [[ ! -d ${PGDATA} ]]; then
      mkdir -p ${PGDATA}
      chown 9999:9999 ${PGDATA}
    fi

  "probe.sh": |
    #!/usr/bin/env bash

    set -o errexit
    set -o nounset
    set -o pipefail

    psql --no-password --username=${POSTGRES_USER} --dbname=${POSTGRES_DB} --command="SELECT 1"

---
apiVersion: v1
kind: Service
metadata:
  namespace: ${namespace_name}
  name: database
spec:
  selector:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "database"
  ports:
    - name: conn
      port: 5432
      targetPort: conn
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  namespace: ${namespace_name}
  name: database
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "database"
spec:
  # When a PVC does not specify a storageClassName,
  # the default StorageClass is used.
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: ${namespace_name}
  name: database
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "database"
    "app.kubernetes.io/name": "postgres"
spec:
  strategy:
    type: Recreate
  replicas: 1
  selector:
    matchLabels:
      "app.kubernetes.io/part-of": "walrus"
      "app.kubernetes.io/component": "database"
      "app.kubernetes.io/name": "postgres"
  template:
    metadata:
      labels:
        "app.kubernetes.io/part-of": "walrus"
        "app.kubernetes.io/component": "database"
        "app.kubernetes.io/name": "postgres"
    spec:
      automountServiceAccountToken: false
      restartPolicy: Always
      initContainers:
        - name: init
          image: postgres:16.1
          imagePullPolicy: IfNotPresent
          command:
            - /script/init.sh
          env:
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: script
              mountPath: /script
            - name: data
              mountPath: /var/lib/postgresql/data
      containers:
        - name: postgres
          image: postgres:16.1
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: '4'
              memory: '8Gi'
            requests:
              cpu: '500m'
              memory: '512Mi'
          securityContext:
            runAsUser: 9999
          ports:
            - name: conn
              containerPort: 5432
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_user
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_password
            - name: POSTGRES_DB
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_name
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          startupProbe:
            failureThreshold: 10
            periodSeconds: 5
            exec:
              command:
                - /script/probe.sh
          readinessProbe:
            failureThreshold: 3
            timeoutSeconds: 5
            periodSeconds: 5
            exec:
              command:
                - /script/probe.sh
          livenessProbe:
            failureThreshold: 3
            timeoutSeconds: 5
            periodSeconds: 10
            exec:
              command:
                - /script/probe.sh
          volumeMounts:
            - name: script
              mountPath: /script
            - name: data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: script
          configMap:
            name: database-script
            defaultMode: 0555
        - name: data
          persistentVolumeClaim:
            claimName: database
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  namespace: ${namespace_name}
  name: minio
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "minio"
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30Gi
---
apiVersion: v1
kind: Service
metadata:
  namespace: ${namespace_name}
  name: minio
spec:
  selector:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "minio"
  ports:
    - name: minio-api
      port: 9000
      targetPort: minio-api
    - name: minio-dashboard
      port: 9001
      targetPort: minio-dashboard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: ${namespace_name}
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "minio"
    "app.kubernetes.io/name": "minio"
spec:
  selector:
    matchLabels:
      "app.kubernetes.io/part-of": "walrus"
      "app.kubernetes.io/component": "minio"
      "app.kubernetes.io/name": "minio"
  strategy:
    type: Recreate
  replicas: 1
  template:
    metadata:
      labels:
        "app.kubernetes.io/part-of": "walrus"
        "app.kubernetes.io/component": "minio"
        "app.kubernetes.io/name": "minio"
    spec:
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: minio
      containers:
      - name: minio
        image: minio/minio:RELEASE.2024-02-26T09-33-48Z
        args:
        - server
        - /storage
        - --console-address
        - ":9001"  # Habilita el dashboard en el puerto 9001
        resources:
          limits:
            cpu: '1'
            memory: '1Gi'
          requests:
            cpu: '500m'
            memory: '512Mi'
        ports:
        - name: minio-api
          containerPort: 9000
        - name: minio-dashboard
          containerPort: 9001
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: walrus
              key: minio_root_user
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: walrus
              key: minio_root_password
        volumeMounts:
        - name: storage
          mountPath: "/storage"

# Identity Access Manager
#
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: ${namespace_name}
  name: identity-access-manager-script
data:
  "init.sh": |
    #!/usr/bin/env bash

    set -o errexit
    set -o nounset
    set -o pipefail

    # validate database
    set +o errexit
    while true; do
      if psql --command="SELECT 1" "${DB_SOURCE}" >/dev/null 2>&1; then
        break
      fi
      echo "waiting db to be ready ..."
      sleep 2s
    done
    set -o errexit

    # mutate app configuration
    cp -f /conf/app.conf app.conf
    sed -i '/^tableNamePrefix =.*/d' app.conf
    echo "tableNamePrefix = casdoor_" >>app.conf
    sed -i '/^driverName =.*/d' app.conf
    echo "driverName = \"${DB_DRIVER}\"" >>app.conf
    sed -i '/^dataSourceName =.*/d' app.conf
    echo "dataSourceName = \"${DB_SOURCE}\"" >>app.conf
    sed -i '/^sessionConfig =.*/d' app.conf
    echo 'sessionConfig = {"enableSetCookie":true,"cookieName":"casdoor_session_id","cookieLifeTime":3600,"providerConfig":"/var/run/casdoor","gclifetime":3600,"domain":"","secure":false,"disableHTTPOnly":false}' >>app.conf
    sed "s#${DB_PASSWORD}#***#g" app.conf

---
apiVersion: v1
kind: Service
metadata:
  namespace: ${namespace_name}
  name: identity-access-manager
spec:
  selector:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "identity-access-manager"
  ports:
    - name: http
      port: 8000
      targetPort: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: ${namespace_name}
  name: identity-access-manager
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "identity-access-manager"
    "app.kubernetes.io/name": "casdoor"
spec:
  replicas: 1
  selector:
    matchLabels:
      "app.kubernetes.io/part-of": "walrus"
      "app.kubernetes.io/component": "identity-access-manager"
      "app.kubernetes.io/name": "casdoor"
  template:
    metadata:
      labels:
        "app.kubernetes.io/part-of": "walrus"
        "app.kubernetes.io/component": "identity-access-manager"
        "app.kubernetes.io/name": "casdoor"
    spec:
      automountServiceAccountToken: false
      restartPolicy: Always
      initContainers:
        - name: init
          image: sealio/casdoor:v1.515.0-seal.1
          imagePullPolicy: IfNotPresent
          workingDir: /tmp/conf
          command:
            - /script/init.sh
          env:
            - name: DB_DRIVER
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_driver
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_user
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_password
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_name
            - name: DB_SOURCE
              value: $(DB_DRIVER)://$(DB_USER):$(DB_PASSWORD)@database:5432/$(DB_NAME)?sslmode=disable
          volumeMounts:
            - name: script
              mountPath: /script
            - name: config
              mountPath: /tmp/conf
      containers:
        - name: casdoor
          image: sealio/casdoor:v1.515.0-seal.1
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: '2'
              memory: '4Gi'
            requests:
              cpu: '500m'
              memory: '512Mi'
          workingDir: /
          command:
            - /casdoor
            - --createDatabase=true
          ports:
            - name: http
              containerPort: 8000
          startupProbe:
            failureThreshold: 10
            periodSeconds: 5

            tcpSocket:
              port: 8000
          readinessProbe:
            failureThreshold: 3
            timeoutSeconds: 5
            periodSeconds: 5
            tcpSocket:
              port: 8000
          livenessProbe:
            failureThreshold: 3
            timeoutSeconds: 5
            periodSeconds: 10
            tcpSocket:
              port: 8000
          volumeMounts:
            - name: config
              mountPath: /conf
            - name: data
              mountPath: /var/run/casdoor
      volumes:
        - name: script
          configMap:
            name: identity-access-manager-script
            defaultMode: 0500
        - name: config
          emptyDir: { }
        - name: data
          emptyDir: { }
---


# Walrus server
#
## RBAC for installing third-party applications.
##
## Since the installation of some third-party software has permission granting operations,
## it will contain some resource global operation permissions, but only for granting.
##
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ${namespace_name}
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
rules:
  - apiGroups:
      - '*'
    resources:
      - '*'
    verbs:
      - '*'
  - nonResourceURLs:
      - '*'
    verbs:
      - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
subjects:
  - kind: ServiceAccount
    name: walrus
    namespace: ${namespace_name}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: walrus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${namespace_name}
  name: walrus-enable-workflow
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
rules:
  - apiGroups:
      - argoproj.io
    resources:
      - "*"
    verbs:
      - "*"
  - apiGroups:
      - ""
    resources:
      - "persistentvolumeclaims"
      - "persistentvolumeclaims/finalizers"
    verbs:
      - "*"
  - apiGroups:
      - ""
    resources:
      - "pods/exec"
    verbs:
      - "*"
  - apiGroups:
      - "policy"
    resources:
      - "poddisruptionbudgets"
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ${namespace_name}
  name: walrus-enable-workflow
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
subjects:
  - kind: ServiceAccount
    name: walrus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: walrus-enable-workflow
## RBAC for deploying
##
## As limiting in the walrus-system, it can be safe to make all verbs as "*".
##
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ${namespace_name}
  name: walrus-deployer
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${namespace_name}
  name: walrus-deployer
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
rules:
  - apiGroups:
      - "batch"
    resources:
      - "jobs"
    verbs:
      - "*"
  - apiGroups:
      - ""
    resources:
      - "secrets"
      - "pods"
      - "pods/log"
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ${namespace_name}
  name: walrus-deployer
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
subjects:
  - kind: ServiceAccount
    name: walrus-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: walrus-deployer
## RBAC for running workflow
##
## As limiting in the walrus-system, it can be safe to make all verbs as "*".
##
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ${namespace_name}
  name: walrus-workflow
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${namespace_name}
  name: walrus-workflow
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
rules:
  # The below rules are used for running workflow.
  - apiGroups:
      - ""
    resources:
      - "pods"
    verbs:
      - "get"
      - "watch"
      - "patch"
  - apiGroups:
      - ""
    resources:
      - "pods/logs"
    verbs:
      - "get"
      - "watch"
  - apiGroups:
      - ""
    resources:
      - "secrets"
    verbs:
      - "get"
  - apiGroups:
      - "argoproj.io"
    resources:
      - "workflowtasksets"
    verbs:
      - "watch"
      - "list"
  - apiGroups:
      - "argoproj.io"
    resources:
      - "workflowtaskresults"
    verbs:
      - "create"
      - "patch"
  - apiGroups:
      - "argoproj.io"
    resources:
      - "workflowtasksets/status"
    verbs:
      - "patch"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ${namespace_name}
  name: walrus-workflow
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
subjects:
  - kind: ServiceAccount
    name: walrus-workflow
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: walrus-workflow
## Storage
##
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  namespace: ${namespace_name}
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
spec:
  # When a PVC does not specify a storageClassName,
  # the default StorageClass is used.
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
## Service
##
---
apiVersion: v1
kind: Service
metadata:
  namespace: ${namespace_name}
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
spec:
  selector:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
  sessionAffinity: ClientIP
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: http
    - name: https
      port: 443
      targetPort: https
## Deployment
##
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: ${namespace_name}
  name: walrus
  labels:
    "app.kubernetes.io/part-of": "walrus"
    "app.kubernetes.io/component": "walrus"
    "app.kubernetes.io/name": "walrus-server"
spec:
  replicas: 1
  selector:
    matchLabels:
      "app.kubernetes.io/part-of": "walrus"
      "app.kubernetes.io/component": "walrus"
      "app.kubernetes.io/name": "walrus-server"
  template:
    metadata:
      labels:
        "app.kubernetes.io/part-of": "walrus"
        "app.kubernetes.io/component": "walrus"
        "app.kubernetes.io/name": "walrus-server"
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: "kubernetes.io/hostname"
                labelSelector:
                  matchExpressions:
                    - key: "app.kubernetes.io/component"
                      operator: In
                      values:
                        - "walrus"
                    - key: "app.kubernetes.io/part-of"
                      operator: In
                      values:
                        - "walrus"
                    - key: "app.kubernetes.io/name"
                      operator: In
                      values:
                        - "walrus-server"
      restartPolicy: Always
      serviceAccountName: walrus
      containers:
        - name: walrus-server
          image: sealio/walrus:v0.6.0
          imagePullPolicy: Always
          resources:
            limits:
              cpu: '4'
              memory: '8Gi'
            requests:
              cpu: '500m'
              memory: '512Mi'
          env:
            - name: DB_DRIVER
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_driver
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_user
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_password
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: db_name
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: minio_root_user
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: minio_root_password
            - name: MINIO_BUCKET
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: minio_bucket
            - name: SERVER_SETTING_LOCAL_ENVIRONMENT_MODE
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: local_environment_mode
            - name: SERVER_ENABLE_TLS
              valueFrom:
                secretKeyRef:
                  name: walrus
                  key: enable_tls
            - name: SERVER_DATA_SOURCE_ADDRESS
              value: $(DB_DRIVER)://$(DB_USER):$(DB_PASSWORD)@database:5432/$(DB_NAME)?sslmode=disable
            - name: SERVER_CASDOOR_SERVER
              value: http://identity-access-manager:8000
          ports:
            - name: http
              containerPort: 80
            - name: https
              containerPort: 443
          startupProbe:
            failureThreshold: 10
            periodSeconds: 5
            httpGet:
              port: 80
              path: /readyz
          readinessProbe:
            failureThreshold: 3
            timeoutSeconds: 5
            periodSeconds: 5
            httpGet:
              port: 80
              path: /readyz
          livenessProbe:
            failureThreshold: 10
            timeoutSeconds: 5
            periodSeconds: 10
            httpGet:
              httpHeaders:
                - name: "User-Agent"
                  value: ""
              port: 80
              path: /livez
          volumeMounts:
            - name: custom-tls
              mountPath: /etc/walrus/ssl
            - name: data
              mountPath: /var/run/walrus
      volumes:
        - name: custom-tls
          secret:
            secretName: walrus-custom-tls
            optional: true
        - name: data
          persistentVolumeClaim:
            claimName: walrus
