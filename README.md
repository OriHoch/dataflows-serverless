# dataflows-serverless

DataFlows-serverless allows to use the [DataFlows](https://github.com/datahq/dataflows) library using serverless concepts.

* Runs on Kubernetes, save costs by starting and stopping the cluster when needed.
* Supports parallel processing of suitable processing steps (e.g. steps which process each row independently).
* Develop and test the processing flow locally using the standard DataFlows library.

## Usage

### Create a flow

Develop a flow locally using the [dataflows](https://github.com/datahq/dataflows) library.

Replace the `Flow` class with `ServerlessFlow` and wrap steps relevant for serverless processing with `serverless_step`

A simple example which downloads from a list of URLs:

```
from dataflows_serverless.flow import ServerlessFlow, serverless_step
from dataflows import dump_to_path
import requests

URLS = ['http://httpbin.org/get?page={}'.format(page) for page in range(100)]

def download(row):
    print('downloading {}'.format(url))
    row['content'] = str(requests.get(row['url']).json())

ServerlessFlow(({'url': url, 'content': ''} for url in URLS),
               serverless_step(download),
               dump_to_path('url_contents')).serverless().process()
```

Save it as `flow.py`, install the dataflows-serverless package and run the flow locally, without serverless:

```
pip3 install dataflows-serverless
python3 flow.py
```

The output data is available at `./url_contents/res_1.csv`

### Setup a Kubernetes cluster

Any recent Kubernetes cluster should work, following are recommended methods to create a cluster

###### Using Google Kubernetes Engine

This is the recommended method both for testing / development and for running production workloads

* If you have problems running locally, try using [Google Cloud Shell](https://cloud.google.com/shell/) which makes the process even easier.
* [Install Google Cloud SDK](https://cloud.google.com/sdk/docs/downloads-interactive)
* Install kubectl:
  * `gcloud components install kubectl`
* Login to Google cloud with application default credentials (ADC):
  * `gcloud auth application-default login`
* Connect to an existing dataflows cluster or create a new one if it doesn't exist:
  * `$(dataflows_serverless_bin)/gke_connect_or_create.sh <GOOGLE_PROJECT_ID>`
* You can configure some additional arguments regarding the created cluster, run the `gke_connect_or_create`
  script without any parameters to see the available arguments.

###### Using Minikube

Minikube is a Kubernetes cluster which runs locally on a virtual machine:

* Install [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
* Start the minikube cluster:
  * `minikube start`
* Switch to the minikube context:
  * `kubectl config use-context minikube`
* Create the dataflows namespace:
  * `kubectl create ns datafows`
* Set the current context to use this namespace by default:
  * `kubectl config set-context minikube --namespace=dataflows`

### Run the flow on the cluster

The following command starts 1 primary job which runs the main flow and 10 secondary jobs which run the serverless steps.

```
python3 flow.py --serverless --secondaries=10 --output-datadir=url_contents
```

The output data is available locally at the same path as the output path of the non-serverless flow: `./url_contents/res_1.csv`

First run can take a while due to pulling of Docker images, subsequent flows will run significantly faster.

If you are using Google Kubernetes Engine, don't forget to delete the cluster when done:

```
$(dataflows_serverless_bin)/gke_cleanup.sh <GOOGLE_PROJECT_ID>
```

## Advanced Usage

### Installing requirements / system dependencies

To install additional requirements for your flow you need to create a Docker image from the dataflows image

Get the relevant docker image by running `dataflows_serverless_image`

The following example Dockerfile adds the Python imaging library:

```
FROM orihoch/dataflows-serverless:9
RUN apk add --update --no-cache zlib-dev jpeg-dev && pip3 install pillow
```

Build and push the modified image. Kubernetes doesn't pull the image if it already exists, so make sure to modify the tag on each image you build.

Run the flow using your modified image

```
python3 flow.py --serverless --secondaries=10 --output-datadir=url_contents --image=your-username/dataflows-serverless-pillow:0.0.1
```

### Providing input data

You can provide input data which will be copied before the jobs are started, all input data should be in a relative path to current working directory

```
python3 flow.py --serverless --secondaries=10 --output-datadir=url_contents --input-datadir=data/input_dir_1 --input-datadir=data/input_dir_2
```

### Advanced data initialization

To provide large data and more advanced data initialization you can provide a data init container.

The following example shows how to use Google Cloud Storage.

Create a data initialization Docker image which copies data to the `/exports/data` directory:

```
FROM google/cloud-sdk
ENTRYPOINT ["bash", "-c", "\
    mkdir -p /exports/data/ &&\
    gcloud --project=GOOGLE_PROJECT_ID auth activate-service-account --key-file=/secrets/service-account.json &&\
    gsutil -m cp -r gs://BUCKET_NAME/data/ /exports/
"]
```

The image needs credentials to access Google Storage, the following script creates a service account for authentication to Google Cloud,
related service account key and Kubernetes secret

```
GOOGLE_PROJECT_ID=
SERVICE_ACCOUNT_NAME=
SECRET_NAME=
gcloud --project=$GOOGLE_PROJECT_ID iam service-accounts create $SERVICE_ACCOUNT_NAME &&\
gcloud projects add-iam-policy-binding $GOOGLE_PROJECT_ID \
    --member "serviceAccount:${SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" \
    --role "roles/storage.objectAdmin" &&\
gcloud iam service-accounts keys create secret-service-account.json --iam-account ${SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com &&\
kubectl create secret generic ${SECRET_NAME} --from-file=service-account.json=secret-service-account.json
```

You will probably need to modify your flow to get the input data from the right directory.

You can check for DATAFLOWS_WORKDIR environment variable to conditionally use the right path on server and locally

```
data_dir = os.path.join(os.environ.get('DATAFLOWS_WORKDIR', '.'), 'data')
```

Run the serverless flow:

```
python3 flow.py --serverless --secondaries=10 --output-datadir=url_contents \
    --data-init-image=your-username/data-init-image --data-init-secret=${SECRET_NAME}
```

To prevent reloading of data you can keep the data server running, provide a unique value for the --nfs-uuid= argument:

```
python3 flow.py --serverless --secondaries=10 --output-datadir=url_contents \
    --data-init-image=your-username/data-init --data-init-secret=${SECRET_NAME} \
    --nfs-uuid=my-nfs
```

Pay attention that in this case, you have to make sure a single primary job is running on each data server.

### Prevent cleanup

Prevent cleanup of created resources - allowing to debug

```
python3 flow.py --serverless --secondaries=10 --output-datadir=url_contents --no-cleanup
```

Doing cleanup can be problematic due to the dynamic nature and usage of NFS, however, the following commands should do it:

```
kubectl delete jobs --all && kubectl delete all --all
```

### Debugging flows remotely

Start the serverless flow in debug mode

```
python3 flow.py --serverless --secondaries=2 --output-datadir=url_contents --debug
```

You will now need to manually run the jobs by executing on the relevant pod, for example:

```
kubectl exec -it PRIMARY_POD_NAME /entrypoint.sh
kubectl exec -it SECONDARY_1_POD_NAME /entrypoint.sh
kubectl exec -it SECONDARY_2_POD_NAME /entrypoint.sh
```

## Updating and publishing a dataflows-serverless release

Update the version in `VERSION.txt`

Update the `DEFAULT_IMAGE` constant in `dataflows_serverless/constants.py` to the new Docker image tag.

Build and publish the Docker image: `docker build -t orihoch/dataflows-serverless:v$(cat VERSION.txt) . && docker push orihoch/dataflows-serverless:v$(cat VERSION.txt)`

Build and publish the package on PyPI: `python setup.py sdist && twine upload dist/dataflows_serverless-$(cat VERSION.txt).tar.gz`
