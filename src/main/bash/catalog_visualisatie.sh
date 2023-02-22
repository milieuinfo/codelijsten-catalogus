#!/bin/bash

sparql --data=/home/gehau/git/codelijsten-catalogus/src/main/resources/be/vlaanderen/omgeving/data/id/catalog/codelijsten-catalogus/catalog.ttl --query ../sparql/catalog_visualisatie.sparql --results=TURTLE | rdf2dot  | dot -Tpng > ../sparql/catalog_visualisatie.png
pushd  ../../..
git pull
mvn clean install
jar=`ls target/*.jar | grep -v sources`
unzip $jar -d target
find target/be  | grep ttl | xargs riot --formatted=TURTLE > /tmp/catalog.ttl
popd
sparql --data=/tmp/catalog.ttl --query ../sparql/catalog_visualisatie.sparql --results=TURTLE | rdf2dot  | dot -Tpng > ../sparql/volledige_catalog_visualisatie.png


