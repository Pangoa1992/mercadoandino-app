# MercadoAndino en AWS (HT-05)

Aplicación de prueba para la tarea **HT-05: Plataforma escalable para MercadoAndino en AWS Learner Lab**
(PIAD-626 Tecnología Cloud con AWS, SENATI).

- **Alumno:** Willy Roy Pasminio Arevalo
- **Región:** us-east-1 (AWS Academy Learner Lab)

## Arquitectura

```
Usuarios ──HTTP 80──> ALB alb-mercadoandino (sg-alb)
                         │
                         ▼
             Target Group tg-mercadoandino (/health)
                         │
             Auto Scaling asg-mercadoandino (min 1 / max 3, CPU 50 %)
             EC2 t3.micro Amazon Linux 2023 (sg-app, LabInstanceProfile)
                         │  URL prefirmada (5 min)
                         ▼
             S3 mercadoandino-uploads-wpa-1627 (privado, versionado, solo HTTPS)
```

- **CloudWatch:** alarma `MercadoAndino-CPU-Alta` (CPU > 70 % por 5 min) → SNS `mercadoandino-alertas`,
  CloudWatch Agent (memoria y disco) y dashboard `MercadoAndino`.
- **CodeDeploy:** aplicación `mercadoandino-app`, grupo `dg-mercadoandino` asociado al ASG
  (las instancias nuevas reciben la última versión automáticamente).

## Contenido

| Archivo | Uso |
|---|---|
| `server.js` | Express: `/`, `/health` y `/api/upload-url` (URL prefirmada de S3) |
| `package.json` | Dependencias `express`, `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner` |
| `appspec.yml` | Archivos a copiar y hooks del despliegue |
| `scripts/` | `stop.sh`, `install.sh`, `start.sh`, `validate.sh` |
| `infra/` | Comandos de CloudShell usados para crear la infraestructura (Paso 0, Op. 01, 02 y 04) |

## Desplegar una versión

```bash
aws deploy push --application-name mercadoandino-app --s3-location s3://mercadoandino-artifacts-wpa-1627/app-v2.zip --source .
aws deploy create-deployment --application-name mercadoandino-app --deployment-group-name dg-mercadoandino \
  --s3-location bucket=mercadoandino-artifacts-wpa-1627,key=app-v2.zip,bundleType=zip
```
