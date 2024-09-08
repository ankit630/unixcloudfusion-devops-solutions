package com.example;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import javax.servlet.RequestDispatcher;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import static org.mockito.Mockito.*;

class TodoServletTest {

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private RequestDispatcher requestDispatcher;

    private TodoServlet todoServlet;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        todoServlet = new TodoServlet();
    }

    @Test
    void testDoPost() throws ServletException, IOException {
        when(request.getParameter("todo")).thenReturn("New Todo Item");
        when(request.getContextPath()).thenReturn("");

        todoServlet.doPost(request, response);

        verify(response).sendRedirect("/");
    }

    @Test
    void testDoGet() throws ServletException, IOException {
        List<String> todos = new ArrayList<>();
        todos.add("Existing Todo Item");

        when(request.getAttribute("todos")).thenReturn(todos);
        when(request.getRequestDispatcher("/index.jsp")).thenReturn(requestDispatcher);

        todoServlet.doGet(request, response);

        verify(request).setAttribute(eq("todos"), anyList());
        verify(requestDispatcher).forward(request, response);
    }
}