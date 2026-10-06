const { HttpError } = require('./errors');
const validate = schema => (req, _res, next) => {
  const parsed = schema.safeParse({ body: req.body, query: req.query, params: req.params });
  if (!parsed.success) return next(new HttpError(400, 'Invalid request', parsed.error.issues.map(i => ({ path: i.path.join('.'), message: i.message }))));
  req.validated = parsed.data;
  next();
};
module.exports = { validate };
