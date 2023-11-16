# Use an official Python runtime as a parent image
FROM python:3.9

# Set the working directory in the container
WORKDIR /app

RUN apt-get update && \
    apt-get install -y hmmer2 hmmer diamond-aligner fasttree prodigal ncbi-blast+ muscle && \
    apt-get clean 

RUN conda install -c bioconda glimmerhmm 
    
# Add tools to the PATH
ENV PATH="/usr/bin:${PATH}"

# Download AntiSMASH and extract it
RUN wget https://dl.secondarymetabolites.org/releases/7.0.1/antismash-7.0.1.tar.gz && \
    tar -zxf antismash-7.0.1.tar.gz && \
    rm antismash-7.0.1.tar.gz

# Install AntiSMASH
RUN pip install ./antismash-7.0.1

# Download AntiSMASH databases
RUN download-antismash-databases
RUN antismash --prepare-data



# CMD to run AntiSMASH when the container launches
CMD ["antismash"]
