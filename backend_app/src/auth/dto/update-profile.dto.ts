/**
 * Input for updating user profile (onboarding / settings).
 * Used with multipart: displayName as form field, photo as optional file.
 */
export interface UpdateProfileInput {
  displayName: string;
  photo?: Express.Multer.File;
}
