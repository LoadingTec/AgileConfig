package com.example.balance;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api")
public class ApiController {

    private static final DateTimeFormatter FILE_STAMP =
            DateTimeFormatter.ofPattern("yyyyMMddHHmmssSSS").withZone(ZoneOffset.UTC);

    private final Path uploadDir;

    public ApiController(@Value("${app.upload-dir:uploads}") String uploadDir) {
        this.uploadDir = Paths.get(uploadDir).toAbsolutePath().normalize();
    }

    @GetMapping(value = "/health", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> health() {
        Map<String, Object> body = new HashMap<>();
        body.put("ok", true);
        body.put("utc", Instant.now().toString());
        try {
            body.put("machine", InetAddress.getLocalHost().getHostName());
        } catch (Exception e) {
            body.put("machine", "unknown");
        }
        return body;
    }

    @PostMapping(value = "/submit", consumes = MediaType.MULTIPART_FORM_DATA_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> submit(
            @RequestParam("name") String name,
            @RequestParam(value = "remark", required = false) String remark,
            @RequestParam(value = "file", required = false) MultipartFile file) throws IOException {

        if (!StringUtils.hasText(name)) {
            Map<String, Object> err = new HashMap<>();
            err.put("error", "name 必填");
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(err);
        }

        Files.createDirectories(uploadDir);

        String savedName = null;
        Long bytes = null;
        if (file != null && !file.isEmpty()) {
            String original = file.getOriginalFilename();
            String safe = (original != null && !original.trim().isEmpty())
                    ? Paths.get(original).getFileName().toString()
                    : "upload.bin";
            savedName = FILE_STAMP.format(Instant.now()) + "_" + safe;
            Path dest = uploadDir.resolve(savedName);
            try (InputStream in = file.getInputStream(); OutputStream out = Files.newOutputStream(dest, StandardOpenOption.CREATE_NEW)) {
                bytes = copyStream(in, out);
            }
        }

        Map<String, Object> body = new HashMap<>();
        body.put("message", "已处理");
        body.put("name", name);
        body.put("remark", remark != null ? remark : "");
        body.put("file", savedName);
        body.put("bytes", bytes);
        return ResponseEntity.ok(body);
    }

    private static long copyStream(InputStream in, OutputStream out) throws IOException {
        byte[] buf = new byte[8192];
        long total = 0;
        int n;
        while ((n = in.read(buf)) != -1) {
            out.write(buf, 0, n);
            total += n;
        }
        return total;
    }
}
