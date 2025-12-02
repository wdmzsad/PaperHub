package com.example.paperhub.admin;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminReportRepository extends JpaRepository<AdminReport, Long> {

    Page<AdminReport> findByStatus(ReportStatus status, Pageable pageable);

    Page<AdminReport> findByTargetType(ReportTargetType type, Pageable pageable);

    Page<AdminReport> findByStatusAndTargetType(ReportStatus status, ReportTargetType type, Pageable pageable);
}


