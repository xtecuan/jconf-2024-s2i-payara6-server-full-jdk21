IMAGE_NAME = quay.io/xtecuan/s2i-payara6-server-full-jdk21
DOMAIN_NAME = production
RUN_NAME = payara6-jdk21
.PHONY: build
build:
	docker build -t $(IMAGE_NAME) .

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
.PHONY: push
push:
	docker push $(IMAGE_NAME):latest

.PHONY: bash
bash:
	docker exec -it $(RUN_NAME) bash 

.PHONY: run
run:
	podman run -d -p 8080:8080 -p 8181:8181 -p 4848:4848 -e DOMAIN_NAME=$(DOMAIN_NAME)  --name $(RUN_NAME) $(IMAGE_NAME):latest
.PHONY: deploy
deploy:
	docker run -d   --privileged   -v /home/xtecuan/NetBeansProjects/logs:/opt/glassfish/appserver/glassfish/domains/spi/logs   -v /home/xtecuan/NetBeansProjects/webappinitiator/target:/opt/glassfish/deployments   -p 8080:8080 -p 8181:8181 -p 4848:4848 -e DOMAIN_NAME=$(DOMAIN_NAME)  --name $(RUN_NAME) $(IMAGE_NAME):latest
.PHONY: stop
stop:
	docker stop $(RUN_NAME)

.PHONY: rm
rm:
	docker rm $(RUN_NAME)

.PHONY: logs
logs:
	docker logs -f  $(RUN_NAME)

