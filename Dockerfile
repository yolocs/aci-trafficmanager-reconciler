FROM microsoft/azure-cli

COPY reconcile.sh .

CMD ["/bin/bash", "-c", "./reconcile.sh"]