#Demonstrate that when using REST APIs your client doesn't need to know anything about the API up front. Just give the correct URL and your good to go

Invoke-RestMethod -Method Get -Uri https://swapi.co/api/people/10/