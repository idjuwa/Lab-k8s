# Lab-k8s
Lab Kubernetes prod-like  (Debian)
Ce lab permet notamment de :

- Tester des déploiements applicatifs Kubernetes
- Valider des pipelines CI/CD (Helm, ArgoCD, Flux…)
- Mettre en place et tester des Ingress Controllers
- Expérimenter des solutions de stockage (CSI, StatefulSets)
- Mettre en œuvre des politiques de sécurité (RBAC, NetworkPolicies)
- Tester l’observabilité (metrics, logs, alerting)
- Simuler des pannes et tester la résilience du cluster

---

## Scénarios de tests possibles

- Perte d’un worker et rescheduling des Pods
- Perte d’un master sans interruption de l’API
- Bascule d’un load balancer
- Rolling upgrade du cluster
- Tests de performance et de montée en charge
- Chaos engineering de base

---

## Public cible

Ce lab est destiné à :
- Équipes DevOps / SRE
- Équipes plateforme
- Formations Kubernetes avancées
- Proof of Concept techniques
- Préparation à une mise en production

---

## Conclusion

Ce Lab fournit un environnement réaliste pour :
- apprendre Kubernetes dans des conditions proches de la production
- sécuriser les mises en production futures
- tester les scénarios critiques avant déploiement réel

Il permet d’identifier les problèmes **avant** qu’ils n’impactent les utilisateurs finaux.
