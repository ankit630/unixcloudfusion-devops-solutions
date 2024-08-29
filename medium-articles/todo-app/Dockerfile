# Stage 1: Build the application
FROM maven:3.8.1-openjdk-11-slim AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package

# Stage 2: Create the runtime image
FROM openjdk:11-jre-slim
WORKDIR /app

# Copy the built artifact from the build stage
# Note: We're using the correct JAR file name here
COPY --from=build /app/target/todo-app.war ./app.war

# Specify the command to run your application
CMD ["java", "-jar", "app.war"]