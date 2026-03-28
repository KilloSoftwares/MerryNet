import { Request, Response, NextFunction } from 'express';
import { authService } from '../services/auth.service';
import { successResponse } from '../utils/errors';

export class AuthController {
  async requestLogin(req: Request, res: Response, next: NextFunction) {
    try {
      const { phone } = req.body;
      const result = await authService.requestLogin(phone);
      res.status(200).json(successResponse(result));
    } catch (error) {
      next(error);
    }
  }

  async verifyOtp(req: Request, res: Response, next: NextFunction) {
    try {
      const { phone, code } = req.body;
      const result = await authService.verifyOtp(phone, code);
      res.status(200).json(successResponse(result));
    } catch (error) {
      next(error);
    }
  }

  async refreshToken(req: Request, res: Response, next: NextFunction) {
    try {
      const { refreshToken } = req.body;
      const result = await authService.refreshAccessToken(refreshToken);
      res.status(200).json(successResponse(result));
    } catch (error) {
      next(error);
    }
  }

  async logout(req: Request, res: Response, next: NextFunction) {
    try {
      const { refreshToken } = req.body;
      await authService.logout(refreshToken);
      res.status(200).json(successResponse({ message: 'Logged out successfully' }));
    } catch (error) {
      next(error);
    }
  }

  async getProfile(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = req.user!.id;
      const profile = await authService.getProfile(userId);
      res.status(200).json(successResponse(profile));
    } catch (error) {
      next(error);
    }
  }
}

export const authController = new AuthController();
