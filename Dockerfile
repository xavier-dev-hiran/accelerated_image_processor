# Use NVIDIA CUDA base image
FROM nvidia/cuda:12.2.0-devel-ubuntu22.04

# Setup environment
ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble

# Install basic dependencies and ROS2 Humble
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    sudo \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update && apt-get install -y \
    ros-humble-ros-base \
    ros-dev-tools \
    python3-rosdep \
    libturbojpeg0-dev \
    libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && rosdep update

# Create workspace
WORKDIR /ros2_ws
COPY . /ros2_ws/src/accelerated_image_processor

# Install dependencies using rosdep and manually install unrecognized keys
RUN apt-get update && apt-get install -y \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libavfilter-dev \
    && rosdep install --from-paths src --ignore-src -y --rosdistro ${ROS_DISTRO} \
    --skip-keys "libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libavfilter-dev" && \
    rm -rf /var/lib/apt/lists/*

# Build the workspace
# Note: Linking against libcuda.so.1 requires the stub to be found at link time.
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 && \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LD_LIBRARY_PATH \
    LIBRARY_PATH=/usr/local/cuda/lib64/stubs:$LIBRARY_PATH \
    colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

# Setup entrypoint
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc
RUN echo "source /ros2_ws/install/setup.bash" >> ~/.bashrc

CMD ["bash"]
