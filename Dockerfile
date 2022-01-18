FROM ubuntu:latest

ARG ANDROID_SDK_VERSION=7583922
ARG CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.21.4/cmake-3.21.4-linux-x86_64.tar.gz
ARG QT_VERSION=6.2.2
ARG QT_MODULES=
ARG QT_ARCH=android_x86
ARG GRADLE_VERSION=7.2
ARG ANDROID_COMPILE_SDK=31
ARG ANDROID_BUILD_TOOLS=31.0.0
ARG NDK_VERSION=22.1.7171670

RUN dpkg --add-architecture i386
RUN apt-get update

RUN apt-get install -y \
	wget \
	curl \
	unzip \
	git \
	g++ \
	make \
	lib32z1 \
	openjdk-11-jdk \
	lib32ncurses6 \
	libbz2-1.0:i386 \
	lib32stdc++6 \
	&& apt-get clean

#install cmake 
RUN wget -qO - ${CMAKE_URL} | tar --strip-components=1 -xz -C /usr/local

#install dependencies for Qt installer & Qt modules
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
	libgl1-mesa-glx \
	libglib2.0-0 \
	python3 \
	python3-pip \
	libfontconfig1 \
	libdbus-1-3 \
	libx11-xcb1 \
	libnss3-dev \
	libasound2-dev \
	libxcomposite1 \
	libxrandr2 \
	libxcursor-dev \
	libegl1-mesa-dev \
	libxi-dev \
	libxss-dev \
	libxtst6 \
	libgl1-mesa-dev \
	&& apt install apt-transport-https ca-certificates wget dirmngr gnupg software-properties-common -y \
	&& wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add - \
	&& add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ \
	&& apt update && apt install adoptopenjdk-8-hotspot -y \
	&& apt-get clean

#download + install Qt
RUN pip3 install aqtinstall 
RUN aqt install-qt --outputdir /opt/qt linux android ${QT_VERSION} ${QT_ARCH} -m ${QT_MODULES}
RUN aqt install-qt --outputdir /opt/qt linux desktop ${QT_VERSION} -m ${QT_MODULES}

ENV PATH /opt/qt/${QT_VERSION}/${QT_ARCH}/bin:$PATH
ENV QT_HOME=/qpt/qt/$${QT_VERSION}/
ENV QT_PLUGIN_PATH /opt/qt/${QT_VERSION}/${QT_ARCH}/plugins/
ENV QML_IMPORT_PATH /opt/qt/${QT_VERSION}/${QT_ARCH}/qml/
ENV QML2_IMPORT_PATH /opt/qt/${QT_VERSION}/${QT_ARCH}/qml/


# download and install Android SDK
# https://developer.android.com/studio#command-tools
ENV ANDROID_SDK_ROOT_PATH /opt/android-sdk

RUN mkdir -p ${ANDROID_SDK_ROOT_PATH}/cmdline-tools && \
	wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip && \
	unzip *tools*linux*.zip -d ${ANDROID_SDK_ROOT_PATH}/cmdline-tools && \
	mv ${ANDROID_SDK_ROOT_PATH}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT_PATH}/cmdline-tools/tools && \
	rm *tools*linux*.zip

# Android SDK
RUN \
	mkdir -p ${ANDROID_SDK_ROOT_PATH}/cmdline-tools && \
	wget --output-document=android-sdk.zip https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip && \
	unzip -d ${ANDROID_SDK_ROOT_PATH}/cmdline-tools android-sdk.zip && \
	rm android-sdk.zip 

RUN \
	echo y | ${ANDROID_SDK_ROOT_PATH}/cmdline-tools/cmdline-tools/bin/sdkmanager "platforms;android-${ANDROID_COMPILE_SDK}"  && \
	echo y | ${ANDROID_SDK_ROOT_PATH}/cmdline-tools/cmdline-tools/bin/sdkmanager "platform-tools"  && \
	echo y | ${ANDROID_SDK_ROOT_PATH}/cmdline-tools/cmdline-tools/bin/sdkmanager "build-tools;${ANDROID_BUILD_TOOLS}"  && \
	echo y | ${ANDROID_SDK_ROOT_PATH}/cmdline-tools/cmdline-tools/bin/sdkmanager --install "ndk;${NDK_VERSION}"  && \
	yes | ${ANDROID_SDK_ROOT_PATH}/cmdline-tools/cmdline-tools/bin/sdkmanager --licenses

ENV NDK_ROOT_PATH=${ANDROID_SDK_ROOT_PATH}/ndk/${NDK_VERSION}
ENV QTDIR=/opt/qt/${QT_VERSION} 
ENV QT_HOST_PATH=/opt/qt/${QT_VERSION}/${QT_ARCH}
ENV	PATH=/opt/qt/${QT_VERSION}/${QT_ARCH}/bin:${PATH} 
ENV	LD_LIBRARY_PATH=/opt/qt/${QT_VERSION}/${QT_ARCH}/lib:${LD_LIBRARY_PATH} 

ENV GRADLE_VERSION 7.2
ENV GRADLE_HOME /usr/local/gradle-${GRADLE_VERSION}
ENV PATH $PATH:$GRADLE_HOME/bin

# Gradle
RUN \
	cd /usr/local && \
	curl -L https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -o gradle-${GRADLE_VERSION}-bin.zip && \
	unzip gradle-${GRADLE_VERSION}-bin.zip && \
	rm gradle-${GRADLE_VERSION}-bin.zip

RUN printf "#!/bin/bash \n \
/opt/qt/${QT_VERSION}/${QT_ARCH}/bin/qt-cmake -DANDROID_SDK_ROOT=/opt/android-sdk/ -DCMAKE_FIND_ROOT_PATH=/opt/qt/${QT_VERSION}/${QT_ARCH}/ -DQT_HOST_PATH=/opt/qt/${QT_VERSION}/gcc_64/ -DCMAKE_TOOLCHAIN_FILE=/opt/android-sdk/ndk/${NDK_VERSION}//build/cmake/android.toolchain.cmake -DQT_NO_GLOBAL_APK_TARET_PART_OF_ALL:BOOL=ON -DANDROID_ABI=x86 -DANDROID_STL=c++_shared -DANDROID_NDK=/opt/android-sdk/ndk/${NDK_VERSION}/ -DQT_QMAKE_EXECUTABLE=/opt/qt/${QT_VERSION}/${QT_ARCH}/bin/qmake -S /project -B /build $@ \n \
cmake --build /build" > /build_android 
RUN chmod u+rx /build_android

WORKDIR /build
ENTRYPOINT [ "/build_android" ]
