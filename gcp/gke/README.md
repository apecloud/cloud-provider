gcloud config set proxy/type socks5
gcloud config set proxy/address 127.0.0.1
gcloud config set proxy/port 2002
gcloud auth login
gcloud config set project $project_id
gcloud components install gke-gcloud-auth-plugin
gcloud container clusters list
gcloud container clusters get-credentials $gke_cluster_name --zone=us-central1-f
