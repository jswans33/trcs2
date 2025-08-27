You are tasked with using the NestJS CLI to generate a codebase for a new feature in a NestJS application. Your goal is to create a clean, maintainable, and well-structured codebase that follows best practices and avoids common pitfalls. Pay close attention to the following guidelines:

1. Avoid using 'ANY' types at all costs.
2. Do not use magic numbers; always use named constants.
3. Avoid hard-coding configuration values.
4. Keep the code simple and avoid unnecessary complexity.
5. Use appropriate design patterns.
6. Utilize the NestJS CLI with full paths for generating components.

You will be provided with two inputs:

<feature_name>
{{FEATURE_NAME}}
</feature_name>

<feature_description>
{{FEATURE_DESCRIPTION}}
</feature_description>

Follow these steps to generate the codebase:

1. Analyze the feature name and description to determine the necessary components (e.g., controller, service, module, dto, entity).

2. Use the NestJS CLI to generate each component. Always use the full path when generating files. For example:

   ```ts
   nest generate controller src/features/feature-name/controllers/feature-name
   nest generate service src/features/feature-name/services/feature-name
   nest generate module src/features/feature-name/feature-name
   ```

3. Create a well-structured folder hierarchy:

```ts
   src/
     features/
       feature-name/
         controllers/
         services/
         dto/
         entities/
         interfaces/
         constants/
         feature-name.module.ts
   ```

4. Implement the necessary logic in each component, ensuring:
   - Strong typing (no 'ANY' types)
   - Use of interfaces and enums where appropriate
   - Dependency injection is properly utilized
   - Business logic is separated from the controller

5. Create DTOs (Data Transfer Objects) for input validation and type safety.

6. If the feature requires database interaction, create an entity and use TypeORM decorators.

7. Define constants in a separate file (e.g., `src/features/feature-name/constants/feature-name.constants.ts`) to avoid magic numbers.

8. Use environment variables for configuration values instead of hard-coding them.

9. Implement error handling using NestJS built-in exception filters or custom exceptions.

10. Write unit tests for the service layer using Jest.

After completing these steps, provide your response in the following format:

<codebase_structure>
Outline the folder structure and files created for the feature.
</codebase_structure>

<cli_commands>
List all NestJS CLI commands used to generate the components.
</cli_commands>

<key_implementation_details>
Describe the key aspects of the implementation, including:
- How you avoided 'ANY' types
- Where and how constants are used
- How configuration values are managed
- Any design patterns or best practices applied
</key_implementation_details>

<potential_improvements>
Suggest any potential improvements or considerations for future development of this feature.
</potential_improvements>

Remember, your final output should only include the content within the tags specified above. Do not include any additional explanations or notes outside of these tags.
