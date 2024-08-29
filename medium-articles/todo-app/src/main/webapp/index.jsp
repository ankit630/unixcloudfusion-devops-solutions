<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.List" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Todo App</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>Todo List</h1>
        <form action="todo" method="post">
            <input type="text" name="todo" placeholder="Enter a new todo" required>
            <button type="submit">Add Todo</button>
        </form>
        <ul>
            <% 
            List<String> todos = (List<String>) request.getAttribute("todos");
            if (todos != null) {
                for (String todo : todos) { 
            %>
                <li><%= todo %></li>
            <% 
                } 
            }
            %>
        </ul>
    </div>
</body>
</html>